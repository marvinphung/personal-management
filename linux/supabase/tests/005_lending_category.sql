set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select public.finance_defaults();
do $$
declare category jsonb; cash jsonb; debt jsonb; txid uuid:=gen_random_uuid(); debtid uuid:=gen_random_uuid(); blocked boolean:=false;
begin
 select to_jsonb(c) into category from public.categories c where c.name='Cho vay';
 if category->>'behavior'<>'lending' then raise exception 'Missing lending behavior'; end if;
 cash=jsonb_build_object('id',txid,'user_id',auth.uid(),'created_at',now(),'updated_at',now(),
 'client_modified_at',now(),'mutation_id',gen_random_uuid(),'type','expense','purpose','normal',
 'amount',1000000,'currency','VND','account_id','a2000000-0000-4000-8000-000000000001',
 'category_id',category->>'id','description','','occurred_at',now());
 begin perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','transactions','data',cash)));
 exception when raise_exception then blocked=true; end;
 if not blocked then raise exception 'Lending recorded as normal spending'; end if;
 cash=cash||jsonb_build_object('purpose','debt_disbursement');
 blocked=false;
 begin perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','transactions','data',cash)));
 exception when raise_exception then blocked=true; end;
 if not blocked then raise exception 'Unlinked lending accepted'; end if;
 debt=jsonb_build_object('id',debtid,'user_id',auth.uid(),'created_at',now(),'updated_at',now(),
 'client_modified_at',now(),'mutation_id',gen_random_uuid(),'person_id','fa6c5a46-87e7-4605-9236-126d1803d197',
 'direction','lent','principal_amount',1000000,'currency','VND','started_at',now(),'status','active','linked_transaction_id',txid);
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(
 jsonb_build_object('table','transactions','data',cash),jsonb_build_object('table','debts','data',debt)));
 if not exists(select 1 from public.finance_debt_balances where id=debtid and remaining_amount=1000000) then raise exception 'Missing linked debt'; end if;
 category=category||jsonb_build_object('name','Cho bạn vay','behavior',null,'client_modified_at',now()+interval '1 second','mutation_id',gen_random_uuid());
 perform public.finance_apply(gen_random_uuid(),jsonb_build_array(jsonb_build_object('table','categories','data',category)));
 if not exists(select 1 from public.categories where id=(category->>'id')::uuid and behavior='lending' and name='Cho bạn vay') then raise exception 'Rename lost lending behavior'; end if;
end $$;
reset role;
