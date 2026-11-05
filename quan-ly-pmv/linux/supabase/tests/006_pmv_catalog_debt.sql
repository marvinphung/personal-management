-- Run in an isolated rollback-only transaction, same style as the existing suite.
insert into auth.users(id) values ('f1000000-0000-4000-8000-000000000001');
insert into public.people(id,user_id,name,mutation_id) values
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','Synthetic person',gen_random_uuid());
insert into public.accounts(id,user_id,name,type,mutation_id) values
 ('f3000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','Synthetic cash','cash',gen_random_uuid());
insert into public.debts(id,user_id,person_id,direction,principal_amount,started_at,mutation_id) values
 ('f4000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001','lent',100000,now(),gen_random_uuid());
set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-4000-8000-000000000001',true);
select public.finance_defaults();
select public.finance_defaults();
do $$
declare changes jsonb; response jsonb; n int; meta jsonb;
begin
 select count(*) into n from public.categories where is_default;
 if n<>20 then raise exception 'Expected 20 PMV categories, got %', n; end if;
 select count(*) into n from public.categories where name in ('Ăn uống','Đi lại','Mua sắm','Công nợ','Đầu tư');
 if n<>7 then raise exception 'Directional categories missing'; end if;
 if exists(select 1 from public.categories where name in ('Học tập','Kinh doanh')) then raise exception 'Removed seed present'; end if;
 if (select count(*) from public.categories where behavior='cong_no_income' and type='income')<>1 then raise exception 'Debt direction seed missing';end if;
 meta=jsonb_build_object('user_id',auth.uid(),'created_at',now(),'updated_at',now(),'client_modified_at',now(),'mutation_id',gen_random_uuid(),'deleted_at',null);
 changes=jsonb_build_array(
  jsonb_build_object('table','transactions','data',meta||jsonb_build_object(
   'id','f5000000-0000-4000-8000-000000000001','type','income','purpose','debt_repayment','amount',120000,'currency','VND',
   'account_id','f3000000-0000-4000-8000-000000000001','description','Synthetic repayment','occurred_at',now())),
  jsonb_build_object('table','debt_payments','data',meta||jsonb_build_object(
   'id','f6000000-0000-4000-8000-000000000001','debt_id','f4000000-0000-4000-8000-000000000001','amount',120000,'paid_at',now(),
   'linked_transaction_id','f5000000-0000-4000-8000-000000000001')));
 response=public.finance_apply('f7000000-0000-4000-8000-000000000001',changes);
 if response->>'conflict'<>'false' then raise exception 'Unexpected conflict';end if;
 perform public.finance_apply('f7000000-0000-4000-8000-000000000001',changes);
 if (select count(*) from public.debt_payments)<>1 then raise exception 'Retry duplicated payment';end if;
 if (select remaining_amount from public.finance_debt_balances where id='f4000000-0000-4000-8000-000000000001')<>-20000 then raise exception 'Overpayment did not persist';end if;
 if (select status from public.debts where id='f4000000-0000-4000-8000-000000000001')<>'active' then raise exception 'Debt automatically completed';end if;
 select to_jsonb(d) into meta from public.debts d where id='f4000000-0000-4000-8000-000000000001';
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','debts','data',meta||jsonb_build_object('status','completed','manual_completed_at',now(),'client_modified_at',now()+interval '1 second','mutation_id',gen_random_uuid()))));
 if (select status from public.debts where id='f4000000-0000-4000-8000-000000000001')<>'completed' then raise exception 'Manual completion not stored';end if;
end $$;
reset role;
