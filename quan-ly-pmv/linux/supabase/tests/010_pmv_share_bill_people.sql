-- Execute on isolated DB after migration 013, inside a rollback transaction.
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='share_bill_payments' and column_name='people_count' and is_nullable='NO' and column_default='1') then
  raise exception 'Missing default people_count';
 end if;
 if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='share_bills' and column_name='manual_completed_at') then
  raise exception 'Missing manual completion marker';
 end if;
end $$;
