-- Campaign-based loyalty cards. Additive migration: legacy cafe memberships and rewards remain intact.
alter table public.cafes
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.cafes
  drop constraint if exists cafes_location_coordinates_check,
  add constraint cafes_location_coordinates_check check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  );

alter table public.campaigns
  add column if not exists stamps_required integer not null default 8,
  add column if not exists reward_title text not null default 'Ödül',
  add column if not exists reward_description text not null default '',
  add column if not exists stamp_icon text not null default 'coffee',
  add column if not exists background_image_url text;

create table if not exists public.campaign_stamp_icons (
  icon_key text primary key check (icon_key ~ '^[a-z][a-z0-9_]{1,31}$'),
  label text not null check (length(trim(label)) between 1 and 40),
  icon_name text not null check (icon_name in (
    'coffee','cake','stamp','pizza','ice_cream','sandwich','star','heart',
    'burger','tea','cookie','donut','gift','leaf','music','book'
  )),
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.campaign_stamp_icons(icon_key,label,icon_name,sort_order) values
  ('coffee','Kahve','coffee',10),
  ('cake','Pasta / tatlı','cake',20),
  ('stamp','Damga','stamp',30),
  ('pizza','Pizza','pizza',40),
  ('ice_cream','Dondurma','ice_cream',50),
  ('sandwich','Sandviç','sandwich',60),
  ('star','Yıldız','star',70),
  ('heart','Kalp','heart',80)
on conflict (icon_key) do nothing;

alter table public.campaign_stamp_icons enable row level security;
grant select, insert, update, delete on public.campaign_stamp_icons to authenticated;

drop policy if exists campaign_stamp_icons_read on public.campaign_stamp_icons;
create policy campaign_stamp_icons_read on public.campaign_stamp_icons
for select to authenticated using (true);

drop policy if exists campaign_stamp_icons_admin_manage on public.campaign_stamp_icons;
create policy campaign_stamp_icons_admin_manage on public.campaign_stamp_icons
for all to authenticated
using (private.is_cafe_admin())
with check (private.is_cafe_admin());

alter table public.campaigns
  drop constraint if exists campaigns_stamps_required_check,
  add constraint campaigns_stamps_required_check check (stamps_required between 1 and 100),
  drop constraint if exists campaigns_stamp_icon_check,
  add constraint campaigns_stamp_icon_fkey
    foreign key (stamp_icon) references public.campaign_stamp_icons(icon_key) on delete restrict;

create table if not exists public.campaign_memberships (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  campaign_id uuid not null references public.campaigns(id) on delete restrict,
  stamps integer not null default 0 check (stamps >= 0),
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, campaign_id)
);

create table if not exists public.campaign_stamp_events (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  campaign_id uuid not null references public.campaigns(id) on delete restrict,
  cafe_id uuid not null references public.cafes(id) on delete restrict,
  issued_by uuid not null references public.profiles(id),
  nfc_tag_id uuid not null references public.nfc_tags(id),
  read_counter bigint not null check (read_counter between 0 and 16777215),
  receipt_reference text not null unique,
  verification_reference text not null,
  created_at timestamptz not null default now(),
  unique (nfc_tag_id, read_counter)
);

alter table public.reward_claims
  add column if not exists campaign_id uuid references public.campaigns(id) on delete set null,
  add column if not exists redemption_code text;

update public.reward_claims
set redemption_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
where redemption_code is null;

alter table public.reward_claims alter column redemption_code set not null;
create unique index if not exists reward_claims_redemption_code_uidx on public.reward_claims(redemption_code);
create unique index if not exists reward_claims_one_issued_per_campaign_uidx
  on public.reward_claims(customer_id, campaign_id) where campaign_id is not null and status = 'issued';
create index if not exists campaign_memberships_customer_idx on public.campaign_memberships(customer_id, joined_at desc);
create index if not exists campaign_stamp_events_campaign_customer_idx on public.campaign_stamp_events(campaign_id, customer_id, created_at desc);

alter table public.campaign_memberships enable row level security;
alter table public.campaign_stamp_events enable row level security;

grant select, insert on public.campaign_memberships to authenticated;
grant select on public.campaign_stamp_events to authenticated;

drop policy if exists campaign_memberships_read_participant on public.campaign_memberships;
create policy campaign_memberships_read_participant on public.campaign_memberships
for select to authenticated
using (
  customer_id = (select auth.uid())
  or exists (
    select 1 from public.campaigns c
    where c.id = campaign_id and private.can_access_cafe(c.cafe_id)
  )
);

drop policy if exists campaign_memberships_join_active on public.campaign_memberships;
create policy campaign_memberships_join_active on public.campaign_memberships
for insert to authenticated
with check (
  customer_id = (select auth.uid())
  and stamps = 0
  and exists (
    select 1
    from public.campaigns c
    join public.cafes f on f.id = c.cafe_id
    where c.id = campaign_id
      and c.is_active
      and f.is_active
      and (c.starts_at is null or c.starts_at <= now())
      and (c.ends_at is null or c.ends_at > now())
      and exists (
        select 1 from public.profiles business_profile
        where business_profile.id = f.business_id
          and business_profile.role = 'business'
          and business_profile.approval_status = 'approved'
      )
  )
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'customer' and p.approval_status = 'approved'
  )
);

drop policy if exists campaign_stamp_events_read_participant on public.campaign_stamp_events;
create policy campaign_stamp_events_read_participant on public.campaign_stamp_events
for select to authenticated
using (
  customer_id = (select auth.uid())
  or private.can_access_cafe(cafe_id)
);

-- The bucket is public for reading campaign artwork; writes remain owner-scoped.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('campaign-backgrounds', 'campaign-backgrounds', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists campaign_backgrounds_public_read on storage.objects;
create policy campaign_backgrounds_public_read on storage.objects
for select to anon, authenticated
using (bucket_id = 'campaign-backgrounds');

drop policy if exists campaign_backgrounds_owner_insert on storage.objects;
create policy campaign_backgrounds_owner_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'campaign-backgrounds'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'business' and p.approval_status = 'approved'
  )
);

drop policy if exists campaign_backgrounds_owner_update on storage.objects;
create policy campaign_backgrounds_owner_update on storage.objects
for update to authenticated
using (
  bucket_id = 'campaign-backgrounds'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'business' and p.approval_status = 'approved')
)
with check (
  bucket_id = 'campaign-backgrounds'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'business' and p.approval_status = 'approved')
);

drop policy if exists campaign_backgrounds_owner_delete on storage.objects;
create policy campaign_backgrounds_owner_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'campaign-backgrounds'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'business' and p.approval_status = 'approved')
);

create or replace function public.issue_verified_campaign_stamp(
  p_customer_id uuid,
  p_campaign_id uuid,
  p_issued_by uuid,
  p_receipt_reference text,
  p_nfc_tag_id uuid,
  p_verification_reference text,
  p_read_counter bigint
)
returns table(new_stamp_count integer, duplicate_blocked boolean, reward_ready boolean)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_business_id uuid;
  v_branch_id uuid;
  v_last_counter bigint;
  v_campaign_business uuid;
  v_goal integer;
  v_current integer;
begin
  if auth.role() <> 'service_role' then raise exception 'Only the verified server endpoint may issue stamps'; end if;
  if p_read_counter < 0 or p_read_counter > 16777215 then raise exception 'Invalid NFC read counter'; end if;
  if p_receipt_reference is null or length(trim(p_receipt_reference)) < 8 then raise exception 'Invalid transaction reference'; end if;
  if p_verification_reference is null or length(trim(p_verification_reference)) < 8 then raise exception 'Missing NFC verification reference'; end if;

  select t.business_id, t.branch_id, t.last_read_counter
    into v_business_id, v_branch_id, v_last_counter
  from public.nfc_tags t
  where t.id = p_nfc_tag_id and t.status = 'active'
  for update;
  if v_business_id is null then raise exception 'NFC tag is not active'; end if;
  if p_read_counter <= v_last_counter then raise exception 'NFC replay detected'; end if;

  if v_branch_id is null then
    select f.id into v_branch_id
    from public.cafes f
    where f.business_id = v_business_id and f.is_active
    order by f.is_main_branch desc, f.created_at, f.id
    limit 1;
  end if;
  if v_branch_id is null or not exists (
    select 1 from public.cafes f where f.id = v_branch_id and f.business_id = v_business_id and f.is_active
  ) then raise exception 'No active branch is assigned to this NFC tag'; end if;

  select f.business_id, c.stamps_required
    into v_campaign_business, v_goal
  from public.campaigns c
  join public.cafes f on f.id = c.cafe_id
  where c.id = p_campaign_id and c.is_active
    and (c.starts_at is null or c.starts_at <= now())
    and (c.ends_at is null or c.ends_at > now());
  if v_campaign_business is null then raise exception 'Campaign is not active'; end if;
  if v_campaign_business <> v_business_id then raise exception 'NFC tag and selected campaign belong to different businesses'; end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved'
  ) then raise exception 'Customer account is not valid'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_business_id and p.role = 'business' and p.approval_status = 'approved'
  ) then raise exception 'Business account is not approved'; end if;
  if p_issued_by <> v_business_id and not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = p_issued_by
      and e.is_active and (e.branch_id is null or e.branch_id = v_branch_id)
  ) then raise exception 'Employee is not authorized for this business'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_campaign_id::text, 0));
  update public.nfc_tags
  set last_read_counter = p_read_counter, last_used_at = now()
  where id = p_nfc_tag_id;

  if not exists (
    select 1 from public.campaign_memberships m
    where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  ) then raise exception 'Customer has not joined this campaign'; end if;

  select m.stamps into v_current
  from public.campaign_memberships m
  where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  for update;

  if coalesce(v_current, 0) >= v_goal then
    return query select coalesce(v_current,0), false, true;
    return;
  end if;

  if exists (
    select 1 from public.campaign_stamp_events e
    where e.customer_id = p_customer_id and e.campaign_id = p_campaign_id
      and e.created_at > now() - interval '10 minutes'
  ) then
    return query select coalesce(v_current,0), true, false;
    return;
  end if;

  insert into public.campaign_stamp_events(
    customer_id,campaign_id,cafe_id,issued_by,nfc_tag_id,read_counter,receipt_reference,verification_reference
  ) values (
    p_customer_id,p_campaign_id,v_branch_id,p_issued_by,p_nfc_tag_id,p_read_counter,
    trim(p_receipt_reference),trim(p_verification_reference)
  );

  update public.campaign_memberships
  set stamps = stamps + 1, updated_at = now()
  where customer_id = p_customer_id and campaign_id = p_campaign_id
  returning stamps into v_current;

  return query select v_current, false, v_current >= v_goal;
end;
$function$;
revoke all on function public.issue_verified_campaign_stamp(uuid,uuid,uuid,text,uuid,text,bigint) from public, anon, authenticated;
grant execute on function public.issue_verified_campaign_stamp(uuid,uuid,uuid,text,uuid,text,bigint) to service_role;

create or replace function public.claim_campaign_reward(
  p_customer_id uuid,
  p_campaign_id uuid
)
returns table(claim_id uuid, redemption_code text)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_cafe_id uuid;
  v_goal integer;
  v_title text;
  v_description text;
  v_campaign_title text;
  v_current integer;
  v_claim_id uuid;
  v_code text;
begin
  if auth.role() <> 'service_role' then raise exception 'Only the verified server endpoint may issue rewards'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved'
  ) then raise exception 'Customer account is not valid'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_campaign_id::text, 0));

  select c.cafe_id,c.stamps_required,c.reward_title,c.reward_description,c.title
    into v_cafe_id,v_goal,v_title,v_description,v_campaign_title
  from public.campaigns c where c.id = p_campaign_id;
  if v_cafe_id is null then raise exception 'Campaign not found'; end if;

  select m.stamps into v_current
  from public.campaign_memberships m
  where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  for update;
  if coalesce(v_current,0) < v_goal then raise exception 'Not enough stamps'; end if;

  select rc.id,rc.redemption_code into v_claim_id,v_code
  from public.reward_claims rc
  where rc.customer_id = p_customer_id and rc.campaign_id = p_campaign_id and rc.status = 'issued'
  limit 1;
  if v_claim_id is not null then
    return query select v_claim_id,v_code;
    return;
  end if;

  v_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.reward_claims(customer_id,cafe_id,campaign_id,stamps_spent,reward_snapshot,redemption_code)
  values (
    p_customer_id,v_cafe_id,p_campaign_id,v_goal,
    jsonb_build_object('title',v_title,'description',v_description,'campaign_title',v_campaign_title),
    v_code
  ) returning id into v_claim_id;

  return query select v_claim_id,v_code;
end;
$function$;
revoke all on function public.claim_campaign_reward(uuid,uuid) from public, anon, authenticated;
grant execute on function public.claim_campaign_reward(uuid,uuid) to service_role;

create or replace function public.redeem_cafe_reward(
  p_claim_id uuid,
  p_redeemed_by uuid
)
returns uuid
language plpgsql security definer set search_path = ''
as $redeem$
declare
  v_business_id uuid;
  v_cafe_id uuid;
  v_campaign_id uuid;
  v_customer_id uuid;
  v_status text;
begin
  if auth.role() <> 'service_role' then raise exception 'Only the verified server endpoint may redeem rewards'; end if;

  select rc.status,rc.cafe_id,rc.campaign_id,rc.customer_id,c.business_id
    into v_status,v_cafe_id,v_campaign_id,v_customer_id,v_business_id
  from public.reward_claims rc
  join public.cafes c on c.id = rc.cafe_id
  where rc.id = p_claim_id
  for update of rc;

  if v_status is null then raise exception 'Reward claim not found'; end if;
  if v_status <> 'issued' then raise exception 'Reward claim is no longer available'; end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_redeemed_by and p.id = v_business_id
      and p.role = 'business' and p.approval_status = 'approved'
  ) and not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = p_redeemed_by
      and e.is_active and (e.branch_id is null or e.branch_id = v_cafe_id)
  ) then raise exception 'User is not authorized to redeem this reward'; end if;

  update public.reward_claims
  set status = 'redeemed', redeemed_by = p_redeemed_by, redeemed_at = now()
  where id = p_claim_id and status = 'issued';
  if not found then raise exception 'Reward claim was already redeemed'; end if;

  if v_campaign_id is not null then
    update public.campaign_memberships
    set stamps = 0, updated_at = now()
    where customer_id = v_customer_id and campaign_id = v_campaign_id;
  end if;

  return p_claim_id;
end;
$redeem$;
revoke all on function public.redeem_cafe_reward(uuid,uuid) from public, anon, authenticated;
grant execute on function public.redeem_cafe_reward(uuid,uuid) to service_role;
