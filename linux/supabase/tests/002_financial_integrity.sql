-- Depends on temporary users from 001; the runner rolls back all tests.
set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
select public.finance_apply('db669f3e-5b69-407c-88ea-4213b78b17b2','[{"table": "accounts", "data": {"id": "7a5f4308-b360-4459-93cc-7bb87a8c67b4", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "ae8ada6e-c459-49ee-a4ba-5277a4a8975a", "deleted_at": null, "name": "Test bank", "type": "bank", "currency": "VND", "opening_balance": 2000000, "icon": null, "is_archived": false}}, {"table": "people", "data": {"id": "fa6c5a46-87e7-4605-9236-126d1803d197", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "6842cca4-5ec7-4672-ad88-296041830ffc", "deleted_at": null, "name": "Test Nam", "phone_optional": null, "note": null}}]'::jsonb);
select public.finance_apply('e65cf108-b79a-4c2e-8297-baaa4728b490','[{"table": "transactions", "data": {"id": "6117812c-b081-4ffa-ada2-ca0401795672", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "89d4bc9e-8d8c-44fb-b6c7-193abceea481", "deleted_at": null, "type": "expense", "purpose": "debt_disbursement", "amount": 1000000, "currency": "VND", "account_id": "7a5f4308-b360-4459-93cc-7bb87a8c67b4", "from_account_id": null, "to_account_id": null, "category_id": null, "description": "Loan", "note": null, "occurred_at": "2026-01-01T00:00:00Z"}}, {"table": "debts", "data": {"id": "b49563d6-4434-4636-909e-7a1a52557f30", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "738a56c6-ac0f-4ea7-ba3c-a518e6f0ce2b", "deleted_at": null, "person_id": "fa6c5a46-87e7-4605-9236-126d1803d197", "direction": "lent", "principal_amount": 1000000, "currency": "VND", "started_at": "2026-01-01T00:00:00Z", "due_at": null, "note": null, "status": "active", "linked_transaction_id": "6117812c-b081-4ffa-ada2-ca0401795672"}}]'::jsonb);
select public.finance_apply('e65cf108-b79a-4c2e-8297-baaa4728b490','[{"table": "transactions", "data": {"id": "6117812c-b081-4ffa-ada2-ca0401795672", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "89d4bc9e-8d8c-44fb-b6c7-193abceea481", "deleted_at": null, "type": "expense", "purpose": "debt_disbursement", "amount": 1000000, "currency": "VND", "account_id": "7a5f4308-b360-4459-93cc-7bb87a8c67b4", "from_account_id": null, "to_account_id": null, "category_id": null, "description": "Loan", "note": null, "occurred_at": "2026-01-01T00:00:00Z"}}, {"table": "debts", "data": {"id": "b49563d6-4434-4636-909e-7a1a52557f30", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "738a56c6-ac0f-4ea7-ba3c-a518e6f0ce2b", "deleted_at": null, "person_id": "fa6c5a46-87e7-4605-9236-126d1803d197", "direction": "lent", "principal_amount": 1000000, "currency": "VND", "started_at": "2026-01-01T00:00:00Z", "due_at": null, "note": null, "status": "active", "linked_transaction_id": "6117812c-b081-4ffa-ada2-ca0401795672"}}]'::jsonb); -- retry exact receipt
select public.finance_apply('c281d749-9d6b-4d43-a71d-810379aac1a7','[{"table": "transactions", "data": {"id": "8120e873-abc5-4d6a-b776-d0f9e14e950a", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "f7ad637a-f805-4ac4-99ba-a80067ede68f", "deleted_at": null, "type": "income", "purpose": "debt_repayment", "amount": 300000, "currency": "VND", "account_id": "7a5f4308-b360-4459-93cc-7bb87a8c67b4", "from_account_id": null, "to_account_id": null, "category_id": null, "description": "Repayment", "note": null, "occurred_at": "2026-01-01T00:00:00Z"}}, {"table": "debt_payments", "data": {"id": "c23df37e-b81f-43d3-a5b6-af0c1abb2f45", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "d1e6fbd3-ae4d-45ee-8378-d5b964adf9df", "deleted_at": null, "debt_id": "b49563d6-4434-4636-909e-7a1a52557f30", "amount": 300000, "paid_at": "2026-01-01T00:00:00Z", "note": null, "linked_transaction_id": "8120e873-abc5-4d6a-b776-d0f9e14e950a"}}]'::jsonb);
do $$ declare amount numeric; n int; begin
 select remaining_amount into amount from public.finance_debt_balances where id='b49563d6-4434-4636-909e-7a1a52557f30';
 if amount<>700000 then raise exception 'Wrong debt remaining'; end if;
 select count(*) into n from public.transactions where id='6117812c-b081-4ffa-ada2-ca0401795672';
 if n<>1 then raise exception 'Retry duplicated ledger row'; end if;
end $$;
do $$ declare blocked boolean:=false; begin
 begin perform public.finance_apply('d470efdf-a4d9-45bc-a84a-5c84958459cd','[{"table": "debt_payments", "data": {"id": "7c46c4ac-dd15-4022-88d1-d3b75f47e6f1", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "963eece1-4e27-4c8a-b7d1-62f298586e8d", "deleted_at": null, "debt_id": "b49563d6-4434-4636-909e-7a1a52557f30", "amount": 800000, "paid_at": "2026-01-01T00:00:00Z", "note": null, "linked_transaction_id": null}}]'::jsonb); exception when others then blocked=true; end;
 if not blocked then raise exception 'Accepted overpayment'; end if;
 if exists(select 1 from public.debt_payments where id='7c46c4ac-dd15-4022-88d1-d3b75f47e6f1') then raise exception 'Failed operation leaked data'; end if;
end $$;
do $$ declare blocked boolean:=false; begin
 begin perform public.finance_apply('252eb2ad-9a5e-4430-a743-0929a82ad97e','[{"table": "transactions", "data": {"id": "5a240dff-7951-4fb6-8074-87670d82718a", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "dfdc0aad-8ead-48ca-9d19-8b1388171f87", "deleted_at": null, "type": "expense", "purpose": "normal", "amount": 5, "currency": "VND", "account_id": "b2000000-0000-4000-8000-000000000001", "from_account_id": null, "to_account_id": null, "category_id": null, "description": "Foreign account", "note": null, "occurred_at": "2026-01-01T00:00:00Z"}}]'::jsonb); exception when others then blocked=true; end;
 if not blocked then raise exception 'Accepted foreign owner reference'; end if;
 if exists(select 1 from public.transactions where id='5a240dff-7951-4fb6-8074-87670d82718a') then raise exception 'Failed operation leaked data'; end if;
end $$;
do $$ declare blocked boolean:=false; begin
 begin perform public.finance_apply('bb6f6199-c4fe-426b-ba16-4da571007c39','[{"table": "tags", "data": {"id": "70c61aeb-37fa-4e6e-bc1d-36a92177b306", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "a669affb-70cd-473c-af32-36f0bfb0fa5e", "deleted_at": null, "name": "atomicity-probe"}}, {"table": "transactions", "data": {"id": "22381ff1-b9c6-46d3-957b-176526b9da85", "user_id": "a1000000-0000-4000-8000-000000000001", "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z", "client_modified_at": "2026-01-01T00:00:00Z", "mutation_id": "1edd0358-4679-4c53-acbf-125d8df85ef4", "deleted_at": null, "type": "expense", "purpose": "normal", "amount": -10, "currency": "VND", "account_id": "7a5f4308-b360-4459-93cc-7bb87a8c67b4", "from_account_id": null, "to_account_id": null, "category_id": null, "description": "", "note": null, "occurred_at": "2026-01-01T00:00:00Z"}}]'::jsonb); exception when others then blocked=true; end;
 if not blocked or exists(select 1 from public.tags where id='70c61aeb-37fa-4e6e-bc1d-36a92177b306') then raise exception 'Atomic rollback failed'; end if;
end $$;
select public.finance_defaults();
select public.finance_defaults();
do $$ declare n int; begin select count(*) into n from public.categories where user_id='a1000000-0000-4000-8000-000000000001' and is_default; if n<>15 then raise exception 'Default categories not idempotent'; end if; end $$;
-- Each syncable table has an owner policy and RLS, independently of grants.
reset role;
do $$ declare tbl text; n int; begin
 foreach tbl in array array['accounts','categories','tags','people','transactions','transaction_tags','debts','debt_payments','notes'] loop
 select count(*) into n from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
 where ns.nspname='public' and c.relname=tbl and c.relrowsecurity and c.relforcerowsecurity;
 if n<>1 then raise exception 'RLS missing on %',tbl;end if;
 select count(*) into n from pg_policies where schemaname='public' and tablename=tbl and policyname in ('owner_select','owner_insert','owner_update');
 if n<>3 then raise exception 'Owner policies missing on %',tbl;end if;
 end loop;
end $$;
set local role authenticated;
-- User B cannot read any of A's newly created finance records or secure view.
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
do $$ declare tbl text; n int; begin
 foreach tbl in array array['accounts','categories','tags','people','transactions','transaction_tags','debts','debt_payments','notes'] loop
 execute format('select count(*) from public.%I where user_id=$1',tbl) into n using 'a1000000-0000-4000-8000-000000000001'::uuid;
 if n<>0 then raise exception 'RLS leak in %',tbl; end if;
 end loop;
 select count(*) into n from public.finance_debt_balances where user_id='a1000000-0000-4000-8000-000000000001';if n<>0 then raise exception 'View bypasses RLS';end if;
end $$;
reset role;
