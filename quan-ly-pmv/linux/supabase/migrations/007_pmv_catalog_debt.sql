-- 007_pmv_catalog_debt.sql
-- Quản lý PMV: Bidirectional Công nợ, Đầu tư behaviors, allow overpayment, manual debt completion, PMV categories & tags seed.

-- 1. Extend debts table with manual_completed_at and 'completed' status
alter table public.debts add column if not exists manual_completed_at timestamptz;
alter table public.debts drop constraint if exists debts_status_check;
alter table public.debts add constraint debts_status_check
 check (status in ('active', 'partially_paid', 'paid', 'cancelled', 'completed'));

-- 2. Extend categories behavior and direction constraints
alter table public.categories drop constraint if exists categories_behavior_check;
alter table public.categories drop constraint if exists lending_category_expense;
alter table public.categories drop constraint if exists categories_behavior_direction;

alter table public.categories add constraint categories_behavior_check
 check (behavior in ('normal', 'lending', 'cong_no_expense', 'cong_no_income', 'investment_expense', 'investment_income'));

alter table public.categories add constraint categories_behavior_direction check (
  (behavior = 'normal') or
  (behavior in ('lending', 'cong_no_expense', 'investment_expense') and type = 'expense') or
  (behavior in ('cong_no_income', 'investment_income') and type = 'income')
);

-- 3. Update category behavior trigger
create or replace function public.finance_category_behavior() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op = 'UPDATE' and old.behavior in ('lending', 'cong_no_expense', 'cong_no_income', 'investment_expense', 'investment_income') then
  new.behavior = old.behavior;
 elsif new.name = 'Cho vay' and new.type = 'expense' and coalesce(new.behavior, 'normal') = 'normal' then
  new.behavior = 'lending';
 elsif new.name = 'Công nợ' and new.type = 'expense' then
  new.behavior = 'cong_no_expense';
 elsif new.name = 'Công nợ' and new.type = 'income' then
  new.behavior = 'cong_no_income';
 elsif new.name = 'Đầu tư' and new.type = 'expense' then
  new.behavior = 'investment_expense';
 elsif new.name = 'Đầu tư' and new.type = 'income' then
  new.behavior = 'investment_income';
 else
  new.behavior = coalesce(new.behavior, 'normal');
 end if;
 return new;
end $$;
revoke all on function public.finance_category_behavior() from public,anon,authenticated;

-- 4. Update lending/debt transaction trigger
create or replace function public.finance_lending_transaction() returns trigger
language plpgsql set search_path='' as $$
declare cat_behavior text;
begin
 if new.deleted_at is null and new.category_id is not null then
  select c.behavior into cat_behavior from public.categories c
   where c.id = new.category_id and c.user_id = new.user_id;
  if cat_behavior = 'lending' and (new.type <> 'expense' or new.purpose <> 'debt_disbursement') then
   raise exception 'Lending category requires a linked debt';
  elsif cat_behavior = 'cong_no_expense' and (new.type <> 'expense' or new.purpose not in ('debt_disbursement', 'debt_repayment')) then
   raise exception 'Expense debt category requires debt_disbursement or debt_repayment';
  elsif cat_behavior = 'cong_no_income' and (new.type <> 'income' or new.purpose not in ('debt_disbursement', 'debt_repayment')) then
   raise exception 'Income debt category requires debt_disbursement or debt_repayment';
  end if;
 end if;
 return new;
end $$;
revoke all on function public.finance_lending_transaction() from public,anon,authenticated;

-- 5. Update finance_apply: remove repayments exceed principal check
create or replace function public.finance_apply(operation_id uuid, changes jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 uid uuid := auth.uid(); item jsonb; body jsonb; tbl text; existing jsonb;
 cols text; updates text; result jsonb; conflict boolean := false;
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if jsonb_typeof(changes)<>'array' or jsonb_array_length(changes) not between 1 and 100 then raise exception 'Invalid operation'; end if;
 -- Serialize each user's writes, including different debts/devices and operation retries.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,7139));
 select o.result into result from public.finance_operations o where o.user_id=uid and o.id=operation_id;
 if found then return result; end if;
 for item in select value from jsonb_array_elements(changes) loop
  tbl=item->>'table'; body=item->'data';
  if tbl not in ('accounts','categories','tags','people','transactions','transaction_tags','debts','debt_payments','notes') then raise exception 'Unknown entity'; end if;
  if (body->>'user_id')::uuid is distinct from uid or (body->>'id')::uuid is null or (body->>'mutation_id')::uuid is null or (body->>'client_modified_at')::timestamptz is null then raise exception 'Invalid owner or metadata' using errcode='42501'; end if;
  if (body->>'client_modified_at')::timestamptz > now()+interval '5 minutes' then raise exception 'Device clock is ahead'; end if;
  execute format('select to_jsonb(t) from public.%I t where id=$1',tbl) into existing using (body->>'id')::uuid;
  if existing is not null then
   if (existing->>'user_id')::uuid<>uid then raise exception 'Invalid owner' using errcode='42501'; end if;
   if ((existing->>'client_modified_at')::timestamptz, existing->>'mutation_id') > ((body->>'client_modified_at')::timestamptz,body->>'mutation_id') then conflict=true; end if;
  end if;
 end loop;
 if not conflict then
  for item in select value from jsonb_array_elements(changes) loop
   tbl=item->>'table'; body=item->'data';
   select string_agg(format('%I',a.attname),',' order by a.attnum),
          string_agg(format('%I=excluded.%I',a.attname,a.attname),',' order by a.attnum) filter(where a.attname not in ('id','user_id','created_at','updated_at'))
   into cols,updates from pg_attribute a where a.attrelid=format('public.%I',tbl)::regclass and a.attnum>0 and not a.attisdropped;
   execute format('insert into public.%1$I (%2$s) select %2$s from jsonb_populate_record(null::public.%1$I,$1) on conflict(id) do update set %3$s',tbl,cols,updates) using body;
  end loop;
  -- Validate the final state inside the same transaction; failures roll everything back.
  if exists(select 1 from public.transactions t join public.accounts a on a.id=coalesce(t.account_id,t.from_account_id) left join public.accounts b on b.id=t.to_account_id where t.user_id=uid and t.deleted_at is null and (t.currency<>a.currency or (b.id is not null and b.currency<>a.currency))) then raise exception 'Account currencies must match'; end if;
  if exists(select 1 from public.transactions t join public.categories c on c.id=t.category_id where t.user_id=uid and t.deleted_at is null and c.type not in ('both',t.type)) then raise exception 'Category type mismatch'; end if;
  -- NOTE: Repayments exceeding principal check removed intentionally for PMV specification.
  if exists(select 1 from public.debt_payments p join public.debts d on d.id=p.debt_id where p.user_id=uid and p.deleted_at is null and (d.deleted_at is not null or d.status='cancelled')) then raise exception 'Debt is not active'; end if;
  if exists(select 1 from public.debts d join public.transactions t on t.id=d.linked_transaction_id where d.user_id=uid and ((d.deleted_at is null)<>(t.deleted_at is null) or t.amount<>d.principal_amount or t.currency<>d.currency or t.purpose<>'debt_disbursement' or t.type<>case d.direction when 'lent' then 'expense' else 'income' end)) then raise exception 'Invalid debt cash movement'; end if;
  if exists(select 1 from public.debt_payments p join public.debts d on d.id=p.debt_id join public.transactions t on t.id=p.linked_transaction_id where p.user_id=uid and ((p.deleted_at is null)<>(t.deleted_at is null) or t.amount<>p.amount or t.currency<>d.currency or t.purpose<>'debt_repayment' or t.type<>case d.direction when 'lent' then 'income' else 'expense' end)) then raise exception 'Invalid repayment cash movement'; end if;
  if exists(select 1 from public.transactions t where t.user_id=uid and t.deleted_at is null and ((t.purpose='debt_disbursement' and not exists(select 1 from public.debts d where d.linked_transaction_id=t.id and d.deleted_at is null)) or (t.purpose='debt_repayment' and not exists(select 1 from public.debt_payments p where p.linked_transaction_id=t.id and p.deleted_at is null)))) then raise exception 'Unlinked debt cash movement'; end if;
 end if;
 result=jsonb_build_object('conflict',conflict);
 insert into public.finance_operations(user_id,id,result) values(uid,operation_id,result);
 return result;
end $$;
revoke all on function public.finance_apply(uuid,jsonb) from public,anon;
grant execute on function public.finance_apply(uuid,jsonb) to authenticated;

-- 6. PMV Categories and Tags Seed Procedure
create or replace function public.finance_pmv_defaults(uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare
 label text; kind text; beh text; suggestions text; category uuid; slug text;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,7139));
 for label, kind, beh, suggestions in select * from (values
   -- Chi (Expense)
   ('Ăn uống', 'expense', 'normal', 'ansang,antrua,antoi,ankhuya,anvat,caphe,nuocuong,douongkhac,dicho,sieuthithucpham,datdoan,nhahang,nhau,tiec'),
   ('Đi lại', 'expense', 'normal', 'doxang,xeom,taxi,guixe,suaxe'),
   ('Mua sắm', 'expense', 'normal', 'quanao,giaydep,phukien,docanhan,dogiadung,dodientu,dodungcongviec'),
   ('Nhà & hóa đơn', 'expense', 'normal', 'tiennha,tiendiennuoc,internet,dienthoai4g5g,phidichvu'),
   ('Giải trí', 'expense', 'normal', 'xemphim,game,nghenhac,dangkydichvu,dichoi,sukienbieudien'),
   ('Sức khỏe', 'expense', 'normal', 'khambenh,thuoc,thethao,baohiem,thucpham'),
   ('Gia đình & quà tặng', 'expense', 'normal', 'bieubome,hotronguoithan,quatang,sinhnhat,damcuoi,damtang,letet'),
   ('Du lịch', 'expense', 'normal', 'dichuyen,luutru,anuong,thamquan,muaqua,tour'),
   ('Chi khác', 'expense', 'normal', 'phinganhang,phigiayto,tuthien,chichuaphanloai'),
   ('Trả sau', 'expense', 'normal', 'shopee,tiktok,thetindung,khac'),
   ('Công nợ', 'expense', 'cong_no_expense', 'chovay,tranno'),
   ('Đầu tư', 'expense', 'investment_expense', 'chungkhoan,quydautu,crypto,vang,tietkiem,gopvon,khacdautu'),

   -- Thu (Income)
   ('Lương', 'income', 'normal', 'luongchinh,phucap,lamthemgio'),
   ('Thưởng', 'income', 'normal', 'thuongthang,thuongquy,thuongtet,thuongduan,thuongkhac'),
   ('Làm thêm', 'income', 'normal', 'viecngoai,freelance,giasu'),
   ('Được tặng', 'income', 'normal', 'giadinh,banbe,nguoiyeu,mungtuoi,quabangtien'),
   ('Thu khác', 'income', 'normal', 'hoantien,laitietkiem,bandocanhan,khacthu'),
   ('Công nợ', 'income', 'cong_no_income', 'thuno,vayno'),
   ('Đầu tư', 'income', 'investment_income', 'chungkhoanthu,quydaututhu,cryptothu,vangthu,tietkiemthu,gopvonthu,khacdaututhu')
 ) d(label, kind, beh, suggestions) loop
   -- Deterministic category ID
   category := md5(uid::text || ':pmvcat:' || kind || ':' || label)::uuid;
   insert into public.categories(id, user_id, name, type, behavior, is_default, mutation_id)
     values(category, uid, label, kind, beh, true, category)
     on conflict(id) do update set behavior = excluded.behavior, is_archived = false;

   foreach slug in array string_to_array(suggestions, ',') loop
     insert into public.tags(id, user_id, name, category_id, mutation_id)
       values(md5(uid::text || ':pmvtag:' || slug)::uuid, uid, slug, category, md5(uid::text || ':pmvtag:' || slug)::uuid)
       on conflict(id) do update set category_id = excluded.category_id, deleted_at = null;
   end loop;
 end loop;
end $$;
revoke all on function public.finance_pmv_defaults(uuid) from public,anon,authenticated;

-- 7. Update finance_defaults() to call finance_pmv_defaults
create or replace function public.finance_defaults() returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid := auth.uid();
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform public.finance_pmv_defaults(uid);
end $$;

-- Preserve normalized bank source fields after confirmation; classification/note remain editable.
alter table public.transactions add column bank_source jsonb;
create function public.finance_bank_source_immutable() returns trigger
language plpgsql set search_path='' as $$
begin
 if old.bank_source is not null and (
  new.bank_source is distinct from old.bank_source or new.amount<>old.amount or
  new.currency<>old.currency or new.type<>old.type or new.description<>old.description or
  new.occurred_at<>old.occurred_at) then
  raise exception 'Bank source fields are read-only';
 end if;
 return new;
end $$;
revoke all on function public.finance_bank_source_immutable() from public,anon,authenticated;
create trigger bank_source_immutable before update on public.transactions
 for each row execute function public.finance_bank_source_immutable();
