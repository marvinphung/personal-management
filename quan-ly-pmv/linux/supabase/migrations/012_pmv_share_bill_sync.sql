-- Add the cloud entities already used by the PMV share-bill client.
-- No existing financial records are modified.
begin;
create table public.share_bills (
 id uuid primary key,
 user_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 expense_tx_id uuid not null unique,
 total_amount numeric(20,0) not null check(total_amount>0 and total_amount<=9000000000000000),
 currency text not null check(currency ~ '^[A-Z]{3}$'),
 num_people integer not null check(num_people>0),
 num_paid integer not null default 0 check(num_paid>=0),
 status text not null default 'active' check(status in ('active','completed')),
 note text, completed_at timestamptz,
 foreign key(user_id,expense_tx_id) references public.transactions(user_id,id)
);
create table public.share_bill_payments (
 id uuid primary key,
 user_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 share_bill_id uuid not null,
 income_tx_id uuid not null unique,
 amount numeric(20,0) not null check(amount>0 and amount<=9000000000000000),
 paid_at timestamptz not null, note text,
 foreign key(user_id,share_bill_id) references public.share_bills(user_id,id),
 foreign key(user_id,income_tx_id) references public.transactions(user_id,id)
);
alter table public.share_bills enable row level security;
alter table public.share_bills force row level security;
create policy owner_select on public.share_bills for select to authenticated using ((select auth.uid())=user_id);
revoke all on public.share_bills from public,anon,authenticated;
grant select on public.share_bills to authenticated;
create index share_bills_sync_idx on public.share_bills(user_id,updated_at,id);
create trigger stamp before insert or update on public.share_bills for each row execute function public.finance_stamp();
alter table public.share_bill_payments enable row level security;
alter table public.share_bill_payments force row level security;
create policy owner_select on public.share_bill_payments for select to authenticated using ((select auth.uid())=user_id);
revoke all on public.share_bill_payments from public,anon,authenticated;
grant select on public.share_bill_payments to authenticated;
create index share_bill_payments_sync_idx on public.share_bill_payments(user_id,updated_at,id);
create trigger stamp before insert or update on public.share_bill_payments for each row execute function public.finance_stamp();
-- Preserve all current RPC validations, idempotency and conflict handling.
do $migration$
declare source text; original text := $$'debts','debt_payments','notes'$$;
begin
 select pg_get_functiondef('public.finance_apply(uuid,jsonb)'::regprocedure) into source;
 if position(original in source)=0 then raise exception 'Unexpected finance_apply allowlist'; end if;
 source:=replace(source,original,$$'debts','debt_payments','notes','share_bills','share_bill_payments'$$);
 execute source;
end $migration$;
notify pgrst, 'reload schema';
commit;
