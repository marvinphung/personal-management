begin;
alter table public.tags add column if not exists display_name text
 check(display_name is null or length(trim(display_name)) between 1 and 100);

create or replace function public.finance_shared_bill_defaults(uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare share uuid; expense record; tag_id uuid; slug text;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,7139));
 select id into share from public.categories where user_id=uid and type='income'
  and name='Nhận share bill' and deleted_at is null;
 if share is null then
  share=md5(uid::text||':pmvcat:income:Nhận share bill')::uuid;
  insert into public.categories(id,user_id,name,type,behavior,is_default,mutation_id)
   values(share,uid,'Nhận share bill','income','normal',true,share)
   on conflict(id) do update set deleted_at=null,is_archived=false;
 end if;
 for expense in select id,name from public.categories where user_id=uid and type in ('expense','both')
  and deleted_at is null and not is_archived loop
  slug='muachung'||replace(expense.id::text,'-','');
  tag_id=md5(uid::text||':pmvshared:buy:'||expense.id::text)::uuid;
  insert into public.tags(id,user_id,name,category_id,display_name,mutation_id)
   values(tag_id,uid,slug,expense.id,'Mua chung',tag_id)
   on conflict(id) do update set category_id=excluded.category_id,display_name=excluded.display_name,deleted_at=null
   where tags.category_id is distinct from excluded.category_id or tags.display_name is distinct from excluded.display_name or tags.deleted_at is not null;
  slug='sharebill'||replace(expense.id::text,'-','');
  tag_id=md5(uid::text||':pmvshared:receive:'||expense.id::text)::uuid;
  insert into public.tags(id,user_id,name,category_id,display_name,mutation_id)
   values(tag_id,uid,slug,share,expense.name,tag_id)
   on conflict(id) do update set category_id=excluded.category_id,display_name=excluded.display_name,deleted_at=null
   where tags.category_id is distinct from excluded.category_id or tags.display_name is distinct from excluded.display_name or tags.deleted_at is not null;
 end loop;
 update public.tags t set deleted_at=now() where t.user_id=uid and t.category_id=share
  and t.name like 'sharebill%' and t.deleted_at is null and not exists(
   select 1 from public.categories c where c.user_id=uid and c.type in ('expense','both')
   and c.deleted_at is null and not c.is_archived and t.name='sharebill'||replace(c.id::text,'-',''));
end $$;
revoke all on function public.finance_shared_bill_defaults(uuid) from public,anon,authenticated;
create or replace function public.finance_defaults() returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501';end if;
 perform public.finance_pmv_defaults(uid);
 perform public.finance_shared_bill_defaults(uid);
end $$;
-- Populate the current single-user PMV catalog too; no transactions are changed.
do $$ declare owner_id uuid; begin
 for owner_id in select distinct user_id from public.categories loop
  perform public.finance_shared_bill_defaults(owner_id);
 end loop;
end $$;
commit;
