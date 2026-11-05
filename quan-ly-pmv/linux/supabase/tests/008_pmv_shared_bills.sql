-- Local rollback fixtures only.
insert into auth.users(id) values ('bc100000-0000-4000-8000-000000000001');
insert into public.categories(id,user_id,name,type,mutation_id) values ('bc200000-0000-4000-8000-000000000001','bc100000-0000-4000-8000-000000000001','Chi tự tạo','expense',gen_random_uuid());
set local role authenticated;
select set_config('request.jwt.claim.sub','bc100000-0000-4000-8000-000000000001',true);
select public.finance_defaults();
select public.finance_defaults();
do $$
declare share uuid; expense_count int; id_count int;
begin
 select id into share from public.categories where name='Nhận share bill' and type='income' and deleted_at is null;
 if share is null then raise exception 'Missing share bill category';end if;
 select count(*) into expense_count from public.categories where type='expense' and deleted_at is null and not is_archived;
 if (select count(*) from public.tags where category_id=share and deleted_at is null)<>expense_count then raise exception 'Share tags do not mirror expenses';end if;
 if exists(select 1 from public.categories c where c.type='expense' and c.deleted_at is null and not c.is_archived and not exists(select 1 from public.tags t where t.user_id=auth.uid() and t.category_id=c.id and t.display_name='Mua chung' and t.deleted_at is null)) then raise exception 'Missing Mua chung';end if;
 if exists(select 1 from public.categories c where c.type='expense' and c.deleted_at is null and not c.is_archived and not exists(select 1 from public.tags t where t.category_id=share and t.display_name=c.name and t.deleted_at is null)) then raise exception 'Share labels differ from expense names';end if;
 select count(*) into id_count from public.tags where name like 'muachung%' and deleted_at is null;
 if id_count<>expense_count then raise exception 'Repeated defaults duplicated shared tags';end if;
end $$;
reset role;
