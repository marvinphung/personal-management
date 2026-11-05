-- Money columns contain INTEGER MINOR UNITS (VND: 1; USD: 1 cent).
-- Fail rather than overwrite any pre-existing table with a conflicting name.
create table public.accounts (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 name text not null check(length(trim(name)) between 1 and 100), type text not null check(type in ('cash','bank','e_wallet','savings','other')), currency text not null default 'VND' check(currency ~ '^[A-Z]{3}$'), opening_balance numeric(20,0) not null default 0, icon text, is_archived boolean not null default false
);
alter table public.accounts enable row level security;
alter table public.accounts force row level security;
create policy owner_select on public.accounts for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.accounts for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.accounts for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.accounts from anon, authenticated;
grant select on public.accounts to authenticated;
create index accounts_sync_idx on public.accounts(user_id,updated_at,id);
create table public.categories (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 name text not null check(length(trim(name)) between 1 and 100), type text not null check(type in ('income','expense','both')), icon text, is_default boolean not null default false, is_archived boolean not null default false
);
alter table public.categories enable row level security;
alter table public.categories force row level security;
create policy owner_select on public.categories for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.categories for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.categories for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.categories from anon, authenticated;
grant select on public.categories to authenticated;
create index categories_sync_idx on public.categories(user_id,updated_at,id);
create table public.tags (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 name text not null check(length(trim(name)) between 1 and 80)
);
alter table public.tags enable row level security;
alter table public.tags force row level security;
create policy owner_select on public.tags for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.tags for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.tags for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.tags from anon, authenticated;
grant select on public.tags to authenticated;
create index tags_sync_idx on public.tags(user_id,updated_at,id);
create table public.people (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 name text not null check(length(trim(name)) between 1 and 100), phone_optional text, note text
);
alter table public.people enable row level security;
alter table public.people force row level security;
create policy owner_select on public.people for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.people for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.people for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.people from anon, authenticated;
grant select on public.people to authenticated;
create index people_sync_idx on public.people(user_id,updated_at,id);
create table public.transactions (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 type text not null check(type in ('income','expense','transfer')), purpose text not null default 'normal' check(purpose in ('normal','debt_disbursement','debt_repayment')), amount numeric(20,0) not null check(amount>0 and amount<=9000000000000000), currency text not null default 'VND', account_id uuid, from_account_id uuid, to_account_id uuid, category_id uuid, description text not null default '', note text, occurred_at timestamptz not null,
 check((type in ('income','expense') and account_id is not null and from_account_id is null and to_account_id is null) or (type='transfer' and account_id is null and from_account_id is not null and to_account_id is not null and from_account_id<>to_account_id and purpose='normal')),
 foreign key(user_id,account_id) references public.accounts(user_id,id),
 foreign key(user_id,from_account_id) references public.accounts(user_id,id),
 foreign key(user_id,to_account_id) references public.accounts(user_id,id),
 foreign key(user_id,category_id) references public.categories(user_id,id)
);
alter table public.transactions enable row level security;
alter table public.transactions force row level security;
create policy owner_select on public.transactions for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.transactions for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.transactions for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.transactions from anon, authenticated;
grant select on public.transactions to authenticated;
create index transactions_sync_idx on public.transactions(user_id,updated_at,id);
create table public.transaction_tags (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 transaction_id uuid not null, tag_id uuid not null, unique(transaction_id,tag_id), foreign key(user_id,transaction_id) references public.transactions(user_id,id), foreign key(user_id,tag_id) references public.tags(user_id,id)
);
alter table public.transaction_tags enable row level security;
alter table public.transaction_tags force row level security;
create policy owner_select on public.transaction_tags for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.transaction_tags for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.transaction_tags for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.transaction_tags from anon, authenticated;
grant select on public.transaction_tags to authenticated;
create index transaction_tags_sync_idx on public.transaction_tags(user_id,updated_at,id);
create table public.debts (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 person_id uuid not null, direction text not null check(direction in ('lent','borrowed')), principal_amount numeric(20,0) not null check(principal_amount>0 and principal_amount<=9000000000000000), currency text not null default 'VND', started_at timestamptz not null, due_at timestamptz, note text, status text not null default 'active' check(status in ('active','partially_paid','paid','cancelled')), linked_transaction_id uuid unique, foreign key(user_id,person_id) references public.people(user_id,id), foreign key(user_id,linked_transaction_id) references public.transactions(user_id,id)
);
alter table public.debts enable row level security;
alter table public.debts force row level security;
create policy owner_select on public.debts for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.debts for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.debts for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.debts from anon, authenticated;
grant select on public.debts to authenticated;
create index debts_sync_idx on public.debts(user_id,updated_at,id);
create table public.debt_payments (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 debt_id uuid not null, amount numeric(20,0) not null check(amount>0 and amount<=9000000000000000), paid_at timestamptz not null, note text, linked_transaction_id uuid unique, foreign key(user_id,debt_id) references public.debts(user_id,id), foreign key(user_id,linked_transaction_id) references public.transactions(user_id,id)
);
alter table public.debt_payments enable row level security;
alter table public.debt_payments force row level security;
create policy owner_select on public.debt_payments for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.debt_payments for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.debt_payments for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.debt_payments from anon, authenticated;
grant select on public.debt_payments to authenticated;
create index debt_payments_sync_idx on public.debt_payments(user_id,updated_at,id);
create table public.notes (
 id uuid primary key,
 user_id uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 client_modified_at timestamptz not null default now(),
 mutation_id uuid not null,
 deleted_at timestamptz,
 unique(user_id,id),
 title text not null check(length(trim(title)) between 1 and 200), content text not null default '', is_pinned boolean not null default false, reminder_at timestamptz, person_id uuid, debt_id uuid, transaction_id uuid, foreign key(user_id,person_id) references public.people(user_id,id), foreign key(user_id,debt_id) references public.debts(user_id,id), foreign key(user_id,transaction_id) references public.transactions(user_id,id)
);
alter table public.notes enable row level security;
alter table public.notes force row level security;
create policy owner_select on public.notes for select to authenticated using ((select auth.uid())=user_id);
create policy owner_insert on public.notes for insert to authenticated with check ((select auth.uid())=user_id);
create policy owner_update on public.notes for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
-- Hard deletes intentionally have no policy; synchronization requires tombstones.
revoke all on public.notes from anon, authenticated;
grant select on public.notes to authenticated;
create index notes_sync_idx on public.notes(user_id,updated_at,id);

create unique index tags_name_unique on public.tags(user_id,lower(name)) where deleted_at is null;
create unique index categories_name_unique on public.categories(user_id,type,lower(name)) where deleted_at is null;
create index transactions_date_idx on public.transactions(user_id,occurred_at desc);
create index people_name_idx on public.people(user_id,name);
create index debts_status_idx on public.debts(user_id,status);
create index debt_payments_debt_idx on public.debt_payments(user_id,debt_id);
create index transaction_tags_transaction_idx on public.transaction_tags(transaction_id);
create index transaction_tags_tag_idx on public.transaction_tags(tag_id);

create function public.finance_stamp() returns trigger language plpgsql set search_path='' as $$
begin
 new.updated_at=clock_timestamp();
 if TG_OP='UPDATE' then new.created_at=old.created_at; end if;
 return new;
end $$;
create trigger stamp before insert or update on public.accounts for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.categories for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.tags for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.people for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.transactions for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.transaction_tags for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.debts for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.debt_payments for each row execute function public.finance_stamp();
create trigger stamp before insert or update on public.notes for each row execute function public.finance_stamp();
