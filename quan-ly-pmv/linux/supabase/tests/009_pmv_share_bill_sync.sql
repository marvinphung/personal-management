-- Fake data only; caller runs in a transaction and rolls back.
insert into auth.users(id) values('c1000000-0000-4000-8000-000000000001'),('c1000000-0000-4000-8000-000000000002');
insert into public.accounts(id,user_id,name,type,mutation_id) values
('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001','Test cash','cash',gen_random_uuid());
insert into public.transactions(id,user_id,mutation_id,type,amount,currency,account_id,occurred_at) values
('c3000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001',gen_random_uuid(),'expense',120000,'VND','c2000000-0000-4000-8000-000000000001',now()),
('c3000000-0000-4000-8000-000000000002','c1000000-0000-4000-8000-000000000001',gen_random_uuid(),'income',60000,'VND','c2000000-0000-4000-8000-000000000001',now());
set local role authenticated;
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
do $$
declare op uuid:=gen_random_uuid(); payload jsonb; result jsonb; blocked boolean:=false;
begin
 payload:=jsonb_build_array(jsonb_build_object('table','share_bills','data',jsonb_build_object(
 'id','c4000000-0000-4000-8000-000000000001','user_id',auth.uid(),
 'created_at',now(),'updated_at',now(),'client_modified_at',now(),'mutation_id',gen_random_uuid(),
 'expense_tx_id','c3000000-0000-4000-8000-000000000001','total_amount',120000,'currency','VND',
 'num_people',2,'num_paid',0,'status','active')));
 result:=public.finance_apply(op,payload);
 if result->>'conflict'<>'false' then raise exception 'Share bill push failed';end if;
 perform public.finance_apply(op,payload);
 if (select count(*) from public.share_bills)<>1 then raise exception 'Retry duplicated bill';end if;
 payload:=jsonb_build_array(jsonb_build_object('table','share_bill_payments','data',jsonb_build_object(
 'id',gen_random_uuid(),'user_id',auth.uid(),'created_at',now(),'updated_at',now(),
 'client_modified_at',now(),'mutation_id',gen_random_uuid(),
 'share_bill_id','c4000000-0000-4000-8000-000000000001','income_tx_id','c3000000-0000-4000-8000-000000000002',
 'amount',60000,'paid_at',now())));
 perform public.finance_apply(gen_random_uuid(),payload);
 if (select count(*) from public.share_bill_payments)<>1 then raise exception 'Payment push failed';end if;
 begin update public.share_bills set num_paid=100;exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'Direct write allowed';end if;
end $$;
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000002',true);
do $$ begin
 if exists(select 1 from public.share_bills) or exists(select 1 from public.share_bill_payments) then raise exception 'RLS isolation failed';end if;
end $$;
reset role;
