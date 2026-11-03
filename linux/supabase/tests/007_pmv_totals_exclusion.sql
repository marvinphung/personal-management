-- Isolated fixtures only. Runner wraps this file in a rollback transaction.
insert into auth.users(id) values ('a1000000-0000-4000-8000-000000000001');
insert into public.people(id,user_id,name,mutation_id) values ('a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Exclusion fixture',gen_random_uuid());
 insert into public.accounts(id,user_id,name,type,mutation_id) values ('a5000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Fixture cash','cash',gen_random_uuid());
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select public.finance_defaults();
do $$
declare meta jsonb; tx jsonb; debt jsonb; investment jsonb; cat uuid;
begin
 meta=jsonb_build_object('user_id',auth.uid(),'created_at',now(),'updated_at',now(),'client_modified_at',now(),'mutation_id',gen_random_uuid(),'deleted_at',null);
 select id into cat from public.categories where behavior='cong_no_expense';
 tx=meta||jsonb_build_object('id','a3000000-0000-4000-8000-000000000001','type','expense','purpose','debt_disbursement','amount',1200000,'currency','VND','account_id',null,'category_id',cat,'description','Fixture loan','occurred_at','2024-01-31T09:00:00Z','exclude_from_totals',true);
 debt=meta||jsonb_build_object('id','a4000000-0000-4000-8000-000000000001','person_id','a2000000-0000-4000-8000-000000000001','direction','lent','principal_amount',1200000,'currency','VND','started_at','2024-01-31T09:00:00Z','status','active','linked_transaction_id',tx->>'id','exclude_from_totals',true);
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','transactions','data',tx),jsonb_build_object('table','debts','data',debt)));
 if (select exclude_from_totals from public.transactions where id=(tx->>'id')::uuid) then raise exception 'Legacy transaction exclusion was not retired';end if;
 if (select exclude_from_totals from public.debts where id=(debt->>'id')::uuid) then raise exception 'Legacy debt exclusion was not retired';end if;
 if (select remaining_amount from public.finance_debt_balances where id=(debt->>'id')::uuid)<>1200000 then raise exception 'Exclusion altered debt balance';end if;
 tx=tx||jsonb_build_object('amount',1000000,'occurred_at','2024-01-30T09:00:00Z','exclude_from_totals',false,'client_modified_at',now()+interval '1 second','mutation_id',gen_random_uuid());
 debt=debt||jsonb_build_object('principal_amount',1000000,'started_at','2024-01-30T09:00:00Z','exclude_from_totals',false,'client_modified_at',now()+interval '1 second','mutation_id',gen_random_uuid());
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','transactions','data',tx),jsonb_build_object('table','debts','data',debt)));
 if (select exclude_from_totals from public.debts where id=(debt->>'id')::uuid) then raise exception 'Debt policy edit lost';end if;
 if (select amount from public.transactions where id=(tx->>'id')::uuid)<>1000000 then raise exception 'Linked edit lost';end if;
 if (select started_at from public.debts where id=(debt->>'id')::uuid) is distinct from (select occurred_at from public.transactions where id=(tx->>'id')::uuid) then raise exception 'Linked dates differ';end if;
 if (select started_at from public.debts where id=(debt->>'id')::uuid)<>'2024-01-30T09:00:00Z'::timestamptz then raise exception 'Selected date lost';end if;
 select id into cat from public.categories where behavior='investment_expense';

 investment=meta||jsonb_build_object('id','a6000000-0000-4000-8000-000000000001','type','expense','purpose','normal','amount',4321,'currency','VND','account_id','a5000000-0000-4000-8000-000000000001','category_id',cat,'description','Fixture investment','occurred_at',now(),'exclude_from_totals',true);
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','transactions','data',investment)));
 if (select exclude_from_totals from public.transactions where id=(investment->>'id')::uuid) then raise exception 'Legacy investment exclusion was not retired';end if;
end $$;
reset role;
