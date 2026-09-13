create table public.finance_operations (
 user_id uuid not null references auth.users(id), id uuid not null,
 result jsonb not null, created_at timestamptz not null default now(), primary key(user_id,id)
);
alter table public.finance_operations enable row level security;
revoke all on public.finance_operations from anon, authenticated;

-- Restricted SECURITY DEFINER boundary: explicit ownership for every input, fixed
-- table allowlist, quoted identifiers, no caller-supplied SQL. Direct writes are revoked.
create function public.finance_apply(operation_id uuid, changes jsonb) returns jsonb
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
  if exists(select 1 from public.debts d where d.user_id=uid and d.deleted_at is null and (select coalesce(sum(p.amount),0) from public.debt_payments p where p.debt_id=d.id and p.deleted_at is null)>d.principal_amount) then raise exception 'Repayments exceed principal'; end if;
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

create function public.finance_defaults() returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); label text; kind text;
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,7139));
 for label,kind in select * from (values ('Food','expense'),('Transport','expense'),('Shopping','expense'),('Education','expense'),('Entertainment','expense'),('Health','expense'),('Bills','expense'),('Housing','expense'),('Other','expense'),('Salary','income'),('Freelance','income'),('Gift','income'),('Investment','income'),('Other Income','income')) d(n,t) loop
  insert into public.categories(id,user_id,name,type,is_default,mutation_id)
  values(md5(uid::text||':category:'||kind||':'||label)::uuid,uid,label,kind,true,md5(uid::text||':category:'||kind||':'||label)::uuid) on conflict do nothing;
 end loop;
end $$;
revoke all on function public.finance_defaults() from public,anon;
grant execute on function public.finance_defaults() to authenticated;

create view public.finance_debt_balances with(security_invoker=true) as
select d.*, d.principal_amount-coalesce(p.paid,0) remaining_amount,
 case when d.status='cancelled' then 'cancelled' when coalesce(p.paid,0)=d.principal_amount then 'paid' when coalesce(p.paid,0)>0 then 'partially_paid' else 'active' end derived_status
from public.debts d left join (select debt_id,sum(amount) paid from public.debt_payments where deleted_at is null group by debt_id) p on p.debt_id=d.id where d.deleted_at is null;
grant select on public.finance_debt_balances to authenticated;
