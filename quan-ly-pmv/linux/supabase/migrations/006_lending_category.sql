-- Semantic category behavior survives display-name edits.
alter table public.categories add column behavior text not null default 'normal'
 check(behavior in ('normal','lending'));
alter table public.categories add constraint lending_category_expense
 check(behavior<>'lending' or type='expense');
update public.categories set behavior='lending',client_modified_at=now()
 where name='Cho vay' and type='expense';
create function public.finance_category_behavior() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' and old.behavior='lending' then
  new.behavior='lending';
 elsif new.name='Cho vay' and new.type='expense' then
  new.behavior='lending';
 else
  new.behavior=coalesce(new.behavior,'normal');
 end if;
 return new;
end $$;
revoke all on function public.finance_category_behavior() from public,anon,authenticated;
create trigger category_behavior before insert or update on public.categories
 for each row execute function public.finance_category_behavior();

-- finance_apply already requires a matching debt in the same atomic batch for
-- every debt_disbursement transaction. Old clients cannot create orphan loans.
create function public.finance_lending_transaction() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.deleted_at is null and exists(select 1 from public.categories c
   where c.id=new.category_id and c.user_id=new.user_id and c.behavior='lending')
   and (new.type<>'expense' or new.purpose<>'debt_disbursement') then
  raise exception 'Lending category requires a linked debt';
 end if;
 return new;
end $$;
revoke all on function public.finance_lending_transaction() from public,anon,authenticated;
create trigger lending_transaction before insert or update on public.transactions
 for each row execute function public.finance_lending_transaction();
