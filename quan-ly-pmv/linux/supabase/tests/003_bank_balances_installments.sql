-- Uses temporary test user; database.py test rolls back the entire run.
reset role;
update public.accounts set bank_balance=5000, bank_balance_at='2026-01-02T00:00:00Z'
 where id='a2000000-0000-4000-8000-000000000001';
update public.accounts set bank_balance=100, bank_balance_at='2026-01-01T00:00:00Z'
 where id='a2000000-0000-4000-8000-000000000001';
do $$ begin
 if (select bank_balance from public.accounts where id='a2000000-0000-4000-8000-000000000001')<>5000 then
 raise exception 'Older snapshot replaced current balance'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
do $$
declare body jsonb; n integer;
begin
 select to_jsonb(t) into body from public.accounts t where id='a2000000-0000-4000-8000-000000000001';
 body=body || jsonb_build_object('bank_balance',0,'bank_balance_at','2026-01-03T00:00:00Z',
   'client_modified_at',clock_timestamp(),'mutation_id',gen_random_uuid());
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','accounts','data',body)));
 if (select bank_balance from public.accounts where id='a2000000-0000-4000-8000-000000000001')<>0 then raise exception 'Zero balance RPC failed'; end if;
 body=jsonb_build_object('id',gen_random_uuid(),'user_id','a1000000-0000-4000-8000-000000000001',
  'created_at',now(),'updated_at',now(),'client_modified_at',clock_timestamp(),'mutation_id',gen_random_uuid(),
  'description','','type','expense','purpose','normal','amount',100000,'currency','VND',
  'account_id','a2000000-0000-4000-8000-000000000001','occurred_at','2090-01-24T00:00:00Z',
  'installment_group',gen_random_uuid(),'installment_number',1,'installment_count',6);
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','transactions','data',body)));
 select count(*) into n from public.transactions where id=(body->>'id')::uuid and installment_count=6 and amount=100000;
 if n<>1 then raise exception 'Installment RPC failed'; end if;
end $$;
reset role;
