-- Initial paid people includes the payer; subsequent receipts add to this base.
begin;
alter table public.share_bills add column initial_paid_people integer not null default 1 check(initial_paid_people>=1);
-- Translate pending bill operations from clients that counted only receipts.
do $migration$
declare source text; marker text := $$tbl=item->>'table'; body=item->'data';$$;
begin
 select pg_get_functiondef('public.finance_apply(uuid,jsonb)'::regprocedure) into source;
 if position(marker in source)=0 then raise exception 'Unexpected finance_apply body mapping';end if;
 source:=replace(source,marker,marker||$patch$
   if tbl='share_bills' and not (body ? 'initial_paid_people') then
    body:=body||jsonb_build_object('initial_paid_people',coalesce(
     (select b.initial_paid_people from public.share_bills b where b.id=(body->>'id')::uuid and b.user_id=uid),1));
    body:=body||jsonb_build_object('num_paid',coalesce((body->>'num_paid')::int,0)+(body->>'initial_paid_people')::int);
    if body->>'status'='active' and (body->>'num_paid')::int >= (body->>'num_people')::int then
     body:=body||jsonb_build_object('status','completed','completed_at',now());
    end if;
   end if;
$patch$);
 execute source;
end $migration$;
notify pgrst,'reload schema';
commit;
