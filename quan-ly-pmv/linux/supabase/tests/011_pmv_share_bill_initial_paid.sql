-- Run after migration 014 against isolated PostgreSQL.
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='share_bills' and column_name='initial_paid_people' and is_nullable='NO' and column_default='1') then
  raise exception 'Missing payer default';
 end if;
 if position('initial_paid_people' in pg_get_functiondef('public.finance_apply(uuid,jsonb)'::regprocedure))=0 then
  raise exception 'Missing old-client bill compatibility';
 end if;
end $$;
