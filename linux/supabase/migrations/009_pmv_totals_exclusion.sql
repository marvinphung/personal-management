-- Legacy outbox payloads omit this field; NULL is treated like false by clients.
-- Nullable columns preserve finance_apply/jsonb_populate_record replay compatibility.
begin;
alter table public.transactions add column if not exists exclude_from_totals boolean default false;
alter table public.debts add column if not exists exclude_from_totals boolean default false;
comment on column public.debts.exclude_from_totals is 'Applies to principal and all linked past/future repayments; balances/history are retained.';
comment on column public.transactions.exclude_from_totals is 'Omit from general income/expense totals and charts, retain actual balances and specialist history.';
commit;
