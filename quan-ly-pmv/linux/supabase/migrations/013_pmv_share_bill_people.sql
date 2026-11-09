-- Each receipt can represent several people; old receipts represent one person.
begin;
alter table public.share_bill_payments add column people_count integer not null default 1 check(people_count>0);
alter table public.share_bills add column manual_completed_at timestamptz;
-- Preserve legacy early manual completion when the distinction is recoverable.
update public.share_bills set manual_completed_at=completed_at
 where status='completed' and num_paid<num_people;
-- jsonb_populate_record inserts explicit NULL for absent keys, so a SQL
-- DEFAULT alone does not protect pending operations from older app versions.
do $migration$
declare source text; marker text := $$tbl=item->>'table'; body=item->'data';$$;
begin
 select pg_get_functiondef('public.finance_apply(uuid,jsonb)'::regprocedure) into source;
 if position(marker in source)=0 then raise exception 'Unexpected finance_apply body mapping';end if;
 source:=replace(source,marker,marker||$patch$
   if tbl='share_bill_payments' and not (body ? 'people_count') then
    body:=body||jsonb_build_object('people_count',1);
   end if;
   if tbl='share_bills' and not (body ? 'manual_completed_at') then
    body:=body||jsonb_build_object('manual_completed_at',
     (select b.manual_completed_at from public.share_bills b where b.id=(body->>'id')::uuid and b.user_id=uid));
   end if;
$patch$);
 execute source;
end $migration$;
notify pgrst, 'reload schema';
commit;
