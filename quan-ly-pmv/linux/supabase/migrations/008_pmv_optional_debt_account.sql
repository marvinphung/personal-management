-- Debt cash flows remain in totals even when no payment account is assigned.
begin;
alter table public.transactions drop constraint transactions_check;
alter table public.transactions add constraint transactions_check check (
 (type in ('income','expense')
  and (account_id is not null or purpose in ('debt_disbursement','debt_repayment'))
  and from_account_id is null and to_account_id is null)
 or (type='transfer' and account_id is null and from_account_id is not null
  and to_account_id is not null and from_account_id<>to_account_id and purpose='normal')
);
commit;
