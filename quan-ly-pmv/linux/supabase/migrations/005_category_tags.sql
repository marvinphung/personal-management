-- Tags now belong to one owned category. No financial/history rows are deleted.
alter table public.tags add column category_id uuid;
alter table public.tags add constraint tags_category_owner_fk
 foreign key(user_id,category_id) references public.categories(user_id,id);
create index tags_category_idx on public.tags(user_id,category_id);

create function public.finance_tag_slug(value text) returns text
language sql immutable set search_path='' as $$
 select regexp_replace(translate(lower(normalize(value, NFC)), 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ', 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'), '[^a-z0-9]', '', 'g')
$$;
revoke all on function public.finance_tag_slug(text) from public,anon,authenticated;

-- Private helper used by authenticated defaults and this one-time migration.
create function public.finance_category_defaults(uid uuid) returns void
language plpgsql security definer set search_path='' as $$
declare original text; label text; kind text; suggestions text; category uuid; slug text; fallback uuid; old record; renamed text;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,7139));
 for original,label,kind,suggestions in select * from (values
('Food','Ăn uống','expense','ansang,antrua,antoi,caphe'),
('Transport','Đi lại','expense','xangxe,guixe,taxi'),
('Shopping','Mua sắm','expense','quanao,giaydep,giadung'),
('Education','Học tập','expense','hocphi,sach,dungcuhoctap'),
('Entertainment','Giải trí','expense','xemphim,dulich,trochoi'),
('Health','Sức khỏe','expense','khambenh,thuoc,thethao'),
('Bills','Hóa đơn','expense','tiendien,tiennuoc,internet'),
('Housing','Nhà ở','expense','tiennha,suachuanha'),
('Other','Khác','expense','canthiet,phatsinh'),
('Salary','Lương','income','luongthang,thuong'),
('Freelance','Làm thêm','income','duan,congviecphu'),
('Gift','Quà tặng','income','quasinhnhat,lixi'),
('Investment','Đầu tư','income','laisuat,cotuc'),
('Other Income','Thu nhập khác','income','hoantien,thunhapphu'),
('Lending','Cho vay','expense','chobanmuon,chonguoithanmuon'),
('Trip','Du lịch','expense','maybay,khachsan,thamquan')
 ) d(original,label,kind,suggestions) loop
  if original='Trip' and not exists(select 1 from public.categories c where c.user_id=uid and c.name in ('Trip','Du lịch') and c.deleted_at is null) then continue; end if;
  -- Preserve existing IDs and references. Only known English labels are translated.
  for old in select c.* from public.categories c where c.user_id=uid and c.type=kind and c.name=original loop
   renamed=label;
   if exists(select 1 from public.categories c where c.user_id=uid and c.type=kind and lower(c.name)=lower(renamed) and c.deleted_at is null and c.id<>old.id) then
    renamed=label||' ('||left(old.id::text,8)||')';
   end if;
   update public.categories set name=renamed, client_modified_at=now() where id=old.id;
  end loop;
  category=null;
  select c.id into category from public.categories c where c.user_id=uid and c.type=kind and c.name=label and c.deleted_at is null limit 1;
  if category is null then
   category=md5(uid::text||':category:'||kind||':'||original)::uuid;
   insert into public.categories(id,user_id,name,type,is_default,mutation_id)
    values(category,uid,label,kind,true,category) on conflict do nothing;
  end if;
  if not exists(select 1 from public.categories c where c.id=category and c.deleted_at is null and not c.is_archived) then continue; end if;
  foreach slug in array string_to_array(suggestions,',') loop
   insert into public.tags(id,user_id,name,category_id,mutation_id)
    values(md5(uid::text||':tag:'||slug)::uuid,uid,slug,category,md5(uid::text||':tag:'||slug)::uuid)
    on conflict do nothing;
  end loop;
 end loop;
end $$;
revoke all on function public.finance_category_defaults(uuid) from public,anon,authenticated;

-- Normalize legacy tags before adding suggestions. Keep IDs and all old links.
do $$
declare item record; slug text;
begin
 for item in select * from public.tags order by id loop
  slug=public.finance_tag_slug(case lower(item.name)
    when 'coffee' then 'cà phê' when 'friends' then 'bạn bè'
    when 'travel' then 'du lịch' when 'university' then 'đại học'
    when 'project' then 'dự án' when 'necessary' then 'cần thiết'
    when 'wasted' then 'lãng phí' when 'shopping' then 'mua sắm'
    when 'boardgame' then 'trò chơi bàn' when 'chinesepool' then 'bi da'
    when 'skincare' then 'chăm sóc da'
    else item.name end);
  if slug='' then slug='tag'; end if;
  if exists(select 1 from public.tags t where t.user_id=item.user_id and lower(t.name)=slug and t.id<>item.id and t.deleted_at is null) then
   slug=left(slug,47)||replace(item.id::text,'-','');
  end if;
  update public.tags set name=slug,client_modified_at=now() where id=item.id;
 end loop;
end $$;

do $$
declare uid uuid;
begin
 for uid in select distinct user_id from public.categories union select distinct user_id from public.tags loop
  perform public.finance_category_defaults(uid);
 end loop;
end $$;

-- Most-used category, stable tie break; otherwise the user's Other category.
update public.tags g set category_id=coalesce(
 (select c.id from public.categories c where g.name='chovay' and c.user_id=g.user_id and c.name='Cho vay' and c.type='expense' and c.deleted_at is null limit 1),
 (select t.category_id from public.transaction_tags l join public.transactions t on t.id=l.transaction_id
   join public.categories c on c.id=t.category_id
   where l.tag_id=g.id and t.user_id=g.user_id and l.deleted_at is null and t.deleted_at is null and c.deleted_at is null
   group by t.category_id order by count(*) desc,t.category_id limit 1),
 (select c.id from public.categories c where c.user_id=g.user_id and c.name='Khác' and c.type='expense' and c.deleted_at is null limit 1),
 (select c.id from public.categories c where c.user_id=g.user_id order by c.deleted_at nulls first,c.id limit 1)
),client_modified_at=now() where g.category_id is null;

-- Keep old clients' pending writes compatible: preserve the existing category,
-- or assign Other for an old unclassified tag. Ownership is still a composite FK.
create function public.finance_prepare_tag() returns trigger
language plpgsql set search_path='' as $$
begin
 new.name=public.finance_tag_slug(new.name);
 if new.category_id is null then
  select category_id into new.category_id from public.tags where id=new.id and user_id=new.user_id;
  if new.category_id is null then
   select id into new.category_id from public.categories where user_id=new.user_id and name='Khác' and type='expense' and deleted_at is null limit 1;
  end if;
 end if;
 return new;
end $$;
revoke all on function public.finance_prepare_tag() from public,anon,authenticated;
create trigger prepare_tag before insert or update on public.tags for each row execute function public.finance_prepare_tag();
alter table public.tags alter column category_id set not null;
alter table public.tags add constraint tags_slug_check check(name ~ '^[a-z0-9]{1,80}$');

create or replace function public.finance_defaults() returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform public.finance_category_defaults(uid);
end $$;
