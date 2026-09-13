-- Keep database values within exact client-supported ranges.
alter table public.accounts add constraint accounts_opening_range check(opening_balance between -9000000000000000 and 9000000000000000);
alter table public.transactions add constraint transactions_currency_code check(currency ~ '^[A-Z]{3}$');
alter table public.debts add constraint debts_currency_code check(currency ~ '^[A-Z]{3}$');
