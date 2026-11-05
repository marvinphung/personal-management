-- Additive: existing accounts and transactions keep their existing behavior.
alter table public.accounts
 add column bank_balance numeric(20,0),
 add column bank_balance_at timestamptz,
 add constraint bank_balance_pair check ((bank_balance is null) = (bank_balance_at is null)),
 add constraint bank_balance_exact check (bank_balance between -9000000000000000 and 9000000000000000);
alter table public.transactions
 add column installment_group uuid,
 add column installment_number integer,
 add column installment_count integer,
 add constraint installment_valid check (
  (installment_group is null and installment_number is null and installment_count is null)
  or (installment_group is not null and installment_number is not null and installment_count is not null
      and type='expense' and purpose='normal' and installment_count between 1 and 60
      and installment_number between 1 and installment_count));
create unique index transaction_installment_unique on public.transactions(user_id, installment_group, installment_number)
 where installment_group is not null;
-- Existing ownership RLS and finance_apply allowlist remain in force. No draft data is added to the cloud.

-- Old clients and late devices must not erase a newer observation while editing a name.
create function public.finance_keep_latest_balance() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.currency is distinct from old.currency then
  new.bank_balance=null; new.bank_balance_at=null;
 elsif old.bank_balance_at is not null and
       (new.bank_balance_at is null or new.bank_balance_at <= old.bank_balance_at) then
  new.bank_balance=old.bank_balance; new.bank_balance_at=old.bank_balance_at;
 end if;
 return new;
end $$;
create trigger keep_latest_bank_balance before update on public.accounts
 for each row execute function public.finance_keep_latest_balance();
