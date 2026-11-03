-- Retire the old flag without removing columns used by durable/older outbox payloads.
begin;
create or replace function public.finance_always_count_totals() returns trigger
language plpgsql set search_path='' as $$
begin
 new.exclude_from_totals=false;
 return new;
end $$;
revoke all on function public.finance_always_count_totals() from public,anon,authenticated;
drop trigger if exists pmv_always_count on public.transactions;
create trigger pmv_always_count before insert or update on public.transactions
 for each row execute function public.finance_always_count_totals();
drop trigger if exists pmv_always_count on public.debts;
create trigger pmv_always_count before insert or update on public.debts
 for each row execute function public.finance_always_count_totals();
update public.transactions set exclude_from_totals=false where exclude_from_totals is distinct from false;
update public.debts set exclude_from_totals=false where exclude_from_totals is distinct from false;
comment on column public.transactions.exclude_from_totals is 'Retired compatibility field; always false. All income/expense movements count in totals.';
comment on column public.debts.exclude_from_totals is 'Retired compatibility field; always false.';
commit;
