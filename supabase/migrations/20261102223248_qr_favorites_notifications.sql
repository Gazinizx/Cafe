-- Additive launch features: secure rotating QR stamps, cafe favorites, and in-app notifications.
create table if not exists public.favorite_cafes (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, cafe_id)
);
alter table public.favorite_cafes enable row level security;
drop policy if exists favorite_cafes_read_own on public.favorite_cafes;
create policy favorite_cafes_read_own on public.favorite_cafes
  for select to authenticated using ((select auth.uid()) = customer_id);
drop policy if exists favorite_cafes_insert_own on public.favorite_cafes;
create policy favorite_cafes_insert_own on public.favorite_cafes
  for insert to authenticated with check (
    (select auth.uid()) = customer_id
    and exists (select 1 from public.cafes c where c.id = cafe_id and c.is_active)
  );
drop policy if exists favorite_cafes_delete_own on public.favorite_cafes;
create policy favorite_cafes_delete_own on public.favorite_cafes
  for delete to authenticated using ((select auth.uid()) = customer_id);
grant select, insert, delete on public.favorite_cafes to authenticated;

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  notification_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists user_notifications_user_created_idx
  on public.user_notifications(user_id, created_at desc);
alter table public.user_notifications enable row level security;
drop policy if exists user_notifications_read_own on public.user_notifications;
create policy user_notifications_read_own on public.user_notifications
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists user_notifications_update_own on public.user_notifications;
create policy user_notifications_update_own on public.user_notifications
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
grant select, update on public.user_notifications to authenticated;

create table if not exists public.campaign_qr_challenges (
  token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
  business_id uuid not null references public.profiles(id) on delete cascade,
  branch_id uuid not null references public.cafes(id) on delete cascade,
  issued_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  check (expires_at > created_at)
);
create index if not exists campaign_qr_challenges_expiry_idx
  on public.campaign_qr_challenges(expires_at) where consumed_at is null;
alter table public.campaign_qr_challenges enable row level security;
revoke all on public.campaign_qr_challenges from anon, authenticated;
grant all on public.campaign_qr_challenges to service_role;

alter table public.campaign_stamp_events alter column nfc_tag_id drop not null;
alter table public.campaign_stamp_events alter column read_counter drop not null;

create or replace function public.issue_campaign_qr_stamp(
  p_token_hash text, p_campaign_id uuid, p_customer_id uuid
)
returns table(new_stamp_count integer, duplicate_blocked boolean, reward_ready boolean)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_business_id uuid;
  v_branch_id uuid;
  v_issued_by uuid;
  v_campaign_business uuid;
  v_goal integer;
  v_current integer;
begin
  if (auth.jwt() ->> 'role') <> 'service_role' then
    raise exception 'Only the verified server endpoint may issue QR stamps';
  end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid QR token';
  end if;
  select q.business_id, q.branch_id, q.issued_by
    into v_business_id, v_branch_id, v_issued_by
  from public.campaign_qr_challenges q
  where q.token_hash = p_token_hash and q.consumed_at is null and q.expires_at > now()
  for update;
  if v_business_id is null then raise exception 'QR code expired or already used'; end if;
  if not exists (
    select 1 from public.cafes f
    where f.id = v_branch_id and f.business_id = v_business_id and f.is_active
  ) then raise exception 'QR branch is no longer active'; end if;
  select f.business_id, c.stamps_required into v_campaign_business, v_goal
  from public.campaigns c join public.cafes f on f.id = c.cafe_id
  where c.id = p_campaign_id and c.is_active
    and (c.starts_at is null or c.starts_at <= now())
    and (c.ends_at is null or c.ends_at > now());
  if v_campaign_business is null then raise exception 'Campaign is not active'; end if;
  if v_campaign_business <> v_business_id then
    raise exception 'QR code and selected campaign belong to different businesses';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved'
  ) then raise exception 'Customer account is not valid'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_business_id and p.role = 'business' and p.approval_status = 'approved'
  ) then raise exception 'Business account is not approved'; end if;
  if v_issued_by <> v_business_id and not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = v_issued_by
      and e.is_active and (e.branch_id is null or e.branch_id = v_branch_id)
  ) then raise exception 'QR issuer is no longer authorized'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_campaign_id::text, 0));
  if not exists (
    select 1 from public.campaign_memberships m
    where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  ) then raise exception 'Customer has not joined this campaign'; end if;
  update public.campaign_qr_challenges set consumed_at = now()
  where token_hash = p_token_hash and consumed_at is null;
  select m.stamps into v_current
  from public.campaign_memberships m
  where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  for update;
  if coalesce(v_current, 0) >= v_goal then
    return query select coalesce(v_current, 0), false, true; return;
  end if;
  if exists (
    select 1 from public.campaign_stamp_events e
    where e.customer_id = p_customer_id and e.campaign_id = p_campaign_id
      and e.created_at > now() - interval '10 minutes'
  ) then
    return query select coalesce(v_current, 0), true, false; return;
  end if;
  insert into public.campaign_stamp_events(
    customer_id, campaign_id, cafe_id, issued_by, nfc_tag_id, read_counter,
    receipt_reference, verification_reference
  ) values (
    p_customer_id, p_campaign_id, v_branch_id, v_issued_by, null, null,
    'QR:' || substr(p_token_hash, 1, 32), p_token_hash
  );
  update public.campaign_memberships set stamps = stamps + 1, updated_at = now()
  where customer_id = p_customer_id and campaign_id = p_campaign_id
  returning stamps into v_current;
  return query select v_current, false, v_current >= v_goal;
end;
$function$;
revoke all on function public.issue_campaign_qr_stamp(text, uuid, uuid) from public, anon, authenticated;
grant execute on function public.issue_campaign_qr_stamp(text, uuid, uuid) to service_role;

create or replace function private.notify_campaign_stamp()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare v_campaign_title text; v_cafe_name text;
begin
  select c.title, f.name into v_campaign_title, v_cafe_name
  from public.campaigns c join public.cafes f on f.id = c.cafe_id
  where c.id = new.campaign_id;
  insert into public.user_notifications(user_id, title, body, notification_type, metadata)
  values (
    new.customer_id, 'Damgan eklendi',
    coalesce(v_cafe_name, 'İşletme') || ' • ' || coalesce(v_campaign_title, 'Kampanya') || ' kartına yeni damga eklendi.',
    'stamp', jsonb_build_object('campaign_id', new.campaign_id, 'cafe_id', new.cafe_id, 'stamp_event_id', new.id)
  );
  return new;
end;
$function$;
revoke all on function private.notify_campaign_stamp() from public, anon, authenticated;
drop trigger if exists campaign_stamp_notification on public.campaign_stamp_events;
create trigger campaign_stamp_notification after insert on public.campaign_stamp_events
for each row execute function private.notify_campaign_stamp();

create or replace function private.notify_reward_issued()
returns trigger language plpgsql security definer set search_path = ''
as $function$
begin
  if new.status = 'issued' then
    insert into public.user_notifications(user_id, title, body, notification_type, metadata)
    values (
      new.customer_id, 'Ödülün hazır!',
      coalesce(new.reward_snapshot ->> 'reward_title', 'Kazandığın ödül') || ' işletmede seni bekliyor.',
      'reward', jsonb_build_object('campaign_id', new.campaign_id, 'reward_claim_id', new.id)
    );
  end if;
  return new;
end;
$function$;
revoke all on function private.notify_reward_issued() from public, anon, authenticated;
drop trigger if exists reward_issued_notification on public.reward_claims;
create trigger reward_issued_notification after insert on public.reward_claims
for each row execute function private.notify_reward_issued();

create or replace function private.notify_business_campaign_join()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare v_business_id uuid; v_campaign_title text;
begin
  select f.business_id, c.title into v_business_id, v_campaign_title
  from public.campaigns c join public.cafes f on f.id = c.cafe_id
  where c.id = new.campaign_id;
  if v_business_id is not null then
    insert into public.user_notifications(user_id, title, body, notification_type, metadata)
    values (
      v_business_id, 'Yeni müşteri kampanyana katıldı',
      coalesce(v_campaign_title, 'Kampanyan') || ' kartına yeni bir müşteri katıldı.',
      'campaign_join', jsonb_build_object('campaign_id', new.campaign_id)
    );
  end if;
  return new;
end;
$function$;
revoke all on function private.notify_business_campaign_join() from public, anon, authenticated;
drop trigger if exists campaign_join_business_notification on public.campaign_memberships;
create trigger campaign_join_business_notification after insert on public.campaign_memberships
for each row execute function private.notify_business_campaign_join();
