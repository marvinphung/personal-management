-- Run in a transaction and ROLLBACK. Temporary auth users never persist.
insert into auth.users(id) values('a1000000-0000-4000-8000-000000000001'),('b1000000-0000-4000-8000-000000000001');
insert into public.accounts(id,user_id,name,type,mutation_id) values
('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','A cash','cash',gen_random_uuid()),
('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','B cash','cash',gen_random_uuid());
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
do $$
declare n int; blocked boolean;
begin
 select count(*) into n from public.accounts where id='b2000000-0000-4000-8000-000000000001';
 if n<>0 then raise exception 'RLS SELECT isolation failed'; end if;
 blocked=false;
 begin update public.accounts set name='stolen' where id='b2000000-0000-4000-8000-000000000001'; exception when insufficient_privilege then blocked=true; end;
 if not blocked then raise exception 'Direct UPDATE should be denied'; end if;
 blocked=false;
 begin delete from public.accounts where id='b2000000-0000-4000-8000-000000000001'; exception when insufficient_privilege then blocked=true; end;
 if not blocked then raise exception 'Direct DELETE should be denied'; end if;
 blocked=false;
 begin insert into public.accounts(id,user_id,name,type,mutation_id) values(gen_random_uuid(),'b1000000-0000-4000-8000-000000000001','spoof','cash',gen_random_uuid()); exception when insufficient_privilege then blocked=true; end;
 if not blocked then raise exception 'Direct INSERT should be denied'; end if;
 blocked=false;
 begin perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','accounts','data',jsonb_build_object('id',gen_random_uuid(),'user_id','b1000000-0000-4000-8000-000000000001','mutation_id',gen_random_uuid(),'client_modified_at',now())))); exception when insufficient_privilege then blocked=true; end;
 if not blocked then raise exception 'RPC owner spoof accepted'; end if;
 blocked=false;
 begin perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','accounts','data',jsonb_build_object('id','b2000000-0000-4000-8000-000000000001','user_id','a1000000-0000-4000-8000-000000000001','mutation_id',gen_random_uuid(),'client_modified_at',now())))); exception when insufficient_privilege then blocked=true; end;
 if not blocked then raise exception 'RPC foreign ID overwrite accepted'; end if;
end $$;
reset role;
