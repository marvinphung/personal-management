-- Runs with synthetic users from 001; the test runner rolls everything back.
set local role authenticated;
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select public.finance_defaults();
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select public.finance_defaults();
do $$
declare before_count int; food uuid; foreign_category uuid; body jsonb; blocked boolean:=false;
begin
 select count(*) into before_count from public.tags;
 perform public.finance_defaults();
 if (select count(*) from public.tags)<>before_count then raise exception 'Duplicate tag defaults'; end if;
 if exists(select 1 from public.tags where category_id is null or name !~ '^[a-z0-9]{1,80}$') then raise exception 'Invalid default tag'; end if;
 if not exists(select 1 from public.categories where name='Cho vay') then raise exception 'Lending category missing'; end if;
 select id into food from public.categories where name='Ăn uống' and type='expense';
 if not exists(select 1 from public.tags where category_id=food and name='caphe') then raise exception 'Food suggestions missing'; end if;
 body=jsonb_build_object('id',gen_random_uuid(),'user_id',auth.uid(),'name','#Đồ uống mới','category_id',food,
  'created_at',now(),'updated_at',now(),'client_modified_at',now(),'mutation_id',gen_random_uuid());
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','tags','data',body)));
 if not exists(select 1 from public.tags where id=(body->>'id')::uuid and name='douongmoi' and category_id=food) then raise exception 'Tag normalization failed'; end if;
 -- Old client body without category must retain association on update.
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','tags','data',body-'category_id')));
 if not exists(select 1 from public.tags where id=(body->>'id')::uuid and category_id=food) then raise exception 'Legacy update lost category'; end if;
 -- Deterministic category ID belonging to user B. IDs are no authorization.
 foreign_category=md5('b1000000-0000-4000-8000-000000000001:category:expense:Food')::uuid;
 begin
  perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','tags','data',body||jsonb_build_object('category_id',foreign_category))));
 exception when foreign_key_violation then blocked=true;
 end;
 if not blocked then raise exception 'Cross-user category accepted'; end if;
 if exists(select 1 from public.tags where user_id<>auth.uid()) then raise exception 'Tag RLS leak'; end if;
 blocked=false;
 begin perform public.finance_category_defaults('b1000000-0000-4000-8000-000000000001');
 exception when insufficient_privilege then blocked=true; end;
 if not blocked then raise exception 'Private defaults exposed'; end if;
end $$;
reset role;
