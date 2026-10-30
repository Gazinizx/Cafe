-- Cafe Dünyam production foundation: branches, staff, NFC registry, rewards and offline payments.
-- Safe additive migration; existing cafes are treated as the initial branch of their owner.

alter table public.cafes
  add column if not exists business_id uuid references public.profiles(id) on delete restrict,
  add column if not exists is_main_branch boolean not null default true;

update public.cafes set business_id = owner_id where business_id is null;
alter table public.cafes alter column business_id set not null;
alter table public.cafes alter column is_main_branch set default false;
with ranked_branches as (
  select id, row_number() over (partition by business_id order by created_at, id) as branch_rank
  from public.cafes
)
update public.cafes c set is_main_branch = (r.branch_rank = 1)
from ranked_branches r where r.id = c.id;
create index if not exists cafes_business_idx on public.cafes(business_id, is_active);

create table if not exists public.business_employees (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.profiles(id) on delete cascade,
  employee_id uuid not null references public.profiles(id) on delete cascade,
  branch_id uuid references public.cafes(id) on delete cascade,
  display_name text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, employee_id)
);

create table if not exists public.nfc_tags (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null unique references public.profiles(id) on delete cascade,
  tag_uid text not null unique,
  secret_reference text not null,
  status text not null default 'pending' check (status in ('pending','active','revoked')),
  provisioned_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz not null default now()
);
comment on column public.nfc_tags.secret_reference is 'Reference to a server-side secret; never store the NFC AES key in this table or expose it to clients.';

create table if not exists public.cafe_rewards (
  cafe_id uuid primary key references public.cafes(id) on delete cascade,
  stamps_required integer not null default 8 check (stamps_required between 1 and 100),
  reward_title text not null,
  reward_description text not null default '',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.reward_claims (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete restrict,
  cafe_id uuid not null references public.cafes(id) on delete restrict,
  redeemed_by uuid references public.profiles(id) on delete set null,
  stamps_spent integer not null check (stamps_spent > 0),
  reward_snapshot jsonb not null default '{}'::jsonb,
  status text not null default 'issued' check (status in ('issued','redeemed','cancelled')),
  created_at timestamptz not null default now(),
  redeemed_at timestamptz
);

create table if not exists public.subscription_packages (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  price_try numeric(10,2) not null check (price_try >= 0),
  billing_period text not null default 'monthly' check (billing_period in ('monthly','yearly')),
  branch_limit integer not null default 1 check (branch_limit > 0),
  employee_limit integer not null default 2 check (employee_limit > 0),
  features jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.profiles(id) on delete cascade,
  package_id uuid not null references public.subscription_packages(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','trialing','active','past_due','cancelled','expired')),
  starts_at timestamptz,
  ends_at timestamptz,
  payment_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists business_subscriptions_owner_idx on public.business_subscriptions(business_id, created_at desc);

create table if not exists public.manual_payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.profiles(id) on delete cascade,
  subscription_id uuid references public.business_subscriptions(id) on delete set null,
  amount_try numeric(10,2) not null check (amount_try >= 0),
  payment_method text not null check (payment_method in ('cash','bank_transfer')),
  status text not null default 'pending' check (status in ('pending','confirmed','rejected')),
  received_by uuid references public.profiles(id) on delete set null,
  reference_note text not null default '',
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists manual_payments_business_idx on public.manual_payments(business_id, created_at desc);

alter table public.stamp_events
  add column if not exists nfc_tag_id uuid references public.nfc_tags(id) on delete restrict,
  add column if not exists branch_id uuid references public.cafes(id) on delete restrict,
  add column if not exists verification_reference text;

alter table public.business_employees enable row level security;
alter table public.nfc_tags enable row level security;
alter table public.cafe_rewards enable row level security;
alter table public.reward_claims enable row level security;
alter table public.subscription_packages enable row level security;
alter table public.business_subscriptions enable row level security;
alter table public.manual_payments enable row level security;

create or replace function public.is_business_member(target_business_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $function$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.id = target_business_id and p.role = 'business' and p.approval_status = 'approved'
  ) or exists (
    select 1 from public.business_employees e
    where e.business_id = target_business_id and e.employee_id = auth.uid() and e.is_active
  );
$function$;
revoke all on function public.is_business_member(uuid) from public;
grant execute on function public.is_business_member(uuid) to anon, authenticated;

-- Employee access is branch-scoped. A NULL branch_id explicitly means all branches.
create or replace function public.can_access_cafe(target_cafe_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $access$
  select public.is_cafe_admin()
    or exists (
      select 1 from public.cafes c
      join public.profiles p on p.id = c.business_id
      where c.id = target_cafe_id and p.id = auth.uid()
        and p.role = 'business' and p.approval_status = 'approved'
    )
    or exists (
      select 1 from public.business_employees e
      join public.cafes c on c.business_id = e.business_id
      where c.id = target_cafe_id and e.employee_id = auth.uid()
        and e.is_active and (e.branch_id is null or e.branch_id = target_cafe_id)
    );
$access$;
revoke all on function public.can_access_cafe(uuid) from public;
grant execute on function public.can_access_cafe(uuid) to anon, authenticated;

drop policy if exists "memberships_read_business" on public.cafe_memberships;
create policy "memberships_read_business" on public.cafe_memberships for select to authenticated
using (public.can_access_cafe(cafe_id));

drop policy if exists "stamp_events_read_business" on public.stamp_events;
create policy "stamp_events_read_business" on public.stamp_events for select to authenticated
using (public.can_access_cafe(cafe_id));

drop policy if exists "business_employees_read" on public.business_employees;
drop policy if exists "business_employees_manage" on public.business_employees;
create policy "business_employees_read" on public.business_employees for select to authenticated
using (business_id = auth.uid() or employee_id = auth.uid() or public.is_cafe_admin());
create policy "business_employees_manage" on public.business_employees for all to authenticated
using ((business_id = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'business' and p.approval_status = 'approved')) or public.is_cafe_admin())
with check ((business_id = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'business' and p.approval_status = 'approved')) or public.is_cafe_admin());

drop policy if exists "nfc_tags_read_owner" on public.nfc_tags;
drop policy if exists "nfc_tags_admin_manage" on public.nfc_tags;
create policy "nfc_tags_read_owner" on public.nfc_tags for select to authenticated
using (business_id = auth.uid() or public.is_cafe_admin());
create policy "nfc_tags_admin_manage" on public.nfc_tags for all to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());

drop policy if exists "cafe_rewards_read_active" on public.cafe_rewards;
drop policy if exists "cafe_rewards_business_manage" on public.cafe_rewards;
create policy "cafe_rewards_read_active" on public.cafe_rewards for select to anon, authenticated
using (is_active or public.can_access_cafe(cafe_id));
create policy "cafe_rewards_business_manage" on public.cafe_rewards for all to authenticated
using (exists (select 1 from public.cafes c where c.id = cafe_id and (c.business_id = auth.uid() or public.is_cafe_admin())))
with check (exists (select 1 from public.cafes c where c.id = cafe_id and (c.business_id = auth.uid() or public.is_cafe_admin())));

drop policy if exists "reward_claims_read_participant" on public.reward_claims;
create policy "reward_claims_read_participant" on public.reward_claims for select to authenticated
using (customer_id = auth.uid() or public.can_access_cafe(cafe_id));

drop policy if exists "subscription_packages_read_active" on public.subscription_packages;
drop policy if exists "subscription_packages_admin_manage" on public.subscription_packages;
create policy "subscription_packages_read_active" on public.subscription_packages for select to anon, authenticated
using (is_active or public.is_cafe_admin());
create policy "subscription_packages_admin_manage" on public.subscription_packages for all to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());

drop policy if exists "business_subscriptions_read_owner" on public.business_subscriptions;
drop policy if exists "business_subscriptions_admin_manage" on public.business_subscriptions;
create policy "business_subscriptions_read_owner" on public.business_subscriptions for select to authenticated
using (business_id = auth.uid() or public.is_cafe_admin());
create policy "business_subscriptions_admin_manage" on public.business_subscriptions for all to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());

drop policy if exists "manual_payments_read_owner" on public.manual_payments;
drop policy if exists "manual_payments_request_owner" on public.manual_payments;
drop policy if exists "manual_payments_admin_manage" on public.manual_payments;
create policy "manual_payments_read_owner" on public.manual_payments for select to authenticated
using (business_id = auth.uid() or public.is_cafe_admin());
create policy "manual_payments_request_owner" on public.manual_payments for insert to authenticated
with check (business_id = auth.uid() and status = 'pending' and received_by is null and paid_at is null);
create policy "manual_payments_admin_manage" on public.manual_payments for all to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());


-- Restrict NFC metadata reads to safe columns; secret references remain server-only.
revoke all on table public.nfc_tags from anon, authenticated;
grant select (id, business_id, tag_uid, status, provisioned_at, last_used_at, created_at)
  on public.nfc_tags to authenticated;

-- New branches must explicitly belong to the signed-in business owner.
drop policy if exists "cafes_owner_insert" on public.cafes;
create policy "cafes_owner_insert" on public.cafes for insert to authenticated with check (
  owner_id = auth.uid() and business_id = auth.uid() and is_active = false
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'business' and p.approval_status = 'approved')
);

-- Preserve the existing signup workflow while setting business_id for the initial branch.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $signup$
declare requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  if requested_role not in ('customer','business') then requested_role := 'customer'; end if;
  insert into public.profiles (id, full_name, email, role, approval_status)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name',''), new.email, requested_role,
          case when requested_role = 'business' then 'pending' else 'approved' end);

  if requested_role = 'business' then
    insert into public.business_applications (
      business_id, cafe_name, phone, business_type, tax_office, tax_number,
      province, district, business_address, delivery_name, delivery_phone,
      delivery_province, delivery_district, delivery_address, tag_count
    ) values (
      new.id, coalesce(new.raw_user_meta_data ->> 'cafe_name','İşletme'),
      new.raw_user_meta_data ->> 'phone', new.raw_user_meta_data ->> 'business_type',
      new.raw_user_meta_data ->> 'tax_office', new.raw_user_meta_data ->> 'tax_number',
      new.raw_user_meta_data ->> 'province', new.raw_user_meta_data ->> 'district',
      new.raw_user_meta_data ->> 'business_address', new.raw_user_meta_data ->> 'delivery_name',
      new.raw_user_meta_data ->> 'delivery_phone', new.raw_user_meta_data ->> 'delivery_province',
      new.raw_user_meta_data ->> 'delivery_district', new.raw_user_meta_data ->> 'delivery_address',
      coalesce(nullif(new.raw_user_meta_data ->> 'tag_count','')::integer, 0)
    );

    insert into public.cafes (owner_id, business_id, name, city, district, address, category, is_active)
    values (
      new.id, new.id, coalesce(new.raw_user_meta_data ->> 'cafe_name','İşletme'),
      coalesce(new.raw_user_meta_data ->> 'province',''), new.raw_user_meta_data ->> 'district',
      new.raw_user_meta_data ->> 'business_address', new.raw_user_meta_data ->> 'business_type', false
    );

    insert into public.business_orders (business_id, order_data, order_status, payment_status)
    values (
      new.id,
      jsonb_build_object(
        'businessName', coalesce(new.raw_user_meta_data ->> 'cafe_name','İşletme'),
        'tagCount', coalesce(nullif(new.raw_user_meta_data ->> 'tag_count','')::integer, 0),
        'packagePriceTry', coalesce(nullif(new.raw_user_meta_data ->> 'package_price_try','')::numeric, 0),
        'shippingTry', coalesce(nullif(new.raw_user_meta_data ->> 'shipping_try','')::numeric, 0),
        'totalTry', coalesce(nullif(new.raw_user_meta_data ->> 'order_total_try','')::numeric, 0),
        'paymentMethod', 'Nakit / banka havalesi (yönetici onaylı)',
        'paymentStatus', 'Ödeme bekliyor',
        'orderStatus', 'Başvuru inceleniyor',
        'recipientName', new.raw_user_meta_data ->> 'delivery_name',
        'recipientPhone', new.raw_user_meta_data ->> 'delivery_phone',
        'province', new.raw_user_meta_data ->> 'delivery_province',
        'district', new.raw_user_meta_data ->> 'delivery_district',
        'address', new.raw_user_meta_data ->> 'delivery_address',
        'createdAt', now()
      ), 'pending', 'pending'
    );
  end if;
  return new;
end;
$signup$;

-- Called only by a trusted Edge Function after the NTAG cryptographic proof is verified.
-- The mobile app must never receive the tag's AES key or direct permission to execute this RPC.
create or replace function public.issue_verified_stamp(
  p_customer_id uuid,
  p_cafe_id uuid,
  p_issued_by uuid,
  p_receipt_reference text,
  p_nfc_tag_id uuid,
  p_verification_reference text
)
returns table(new_stamp_count integer, duplicate_blocked boolean)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_business_id uuid;
  v_goal integer;
  v_count integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the verified server endpoint may issue stamps';
  end if;
  if p_receipt_reference is null or length(trim(p_receipt_reference)) < 8 then
    raise exception 'Invalid transaction reference';
  end if;
  select c.business_id into v_business_id
  from public.cafes c
  where c.id = p_cafe_id and c.is_active;
  if v_business_id is null then raise exception 'Cafe is not active'; end if;
  if not exists (
    select 1 from public.nfc_tags t
    where t.id = p_nfc_tag_id and t.business_id = v_business_id and t.status = 'active'
  ) then raise exception 'NFC tag is not active for this business'; end if;
  if not exists (
    select 1 from public.profiles p where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved'
  ) then raise exception 'Customer account is not valid'; end if;
  if not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = p_issued_by and e.is_active
      and (e.branch_id is null or e.branch_id = p_cafe_id)
  ) and p_issued_by <> v_business_id then
    raise exception 'Employee is not authorized for this business';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_cafe_id::text, 0));
  if exists (
    select 1 from public.stamp_events e
    where e.customer_id = p_customer_id and e.cafe_id = p_cafe_id
      and e.created_at > now() - interval '10 minutes'
  ) then
    return query select coalesce((select m.stamps from public.cafe_memberships m where m.customer_id = p_customer_id and m.cafe_id = p_cafe_id), 0), true;
    return;
  end if;

  insert into public.stamp_events(customer_id, cafe_id, issued_by, receipt_reference, nfc_tag_id, branch_id, verification_reference)
  values (p_customer_id, p_cafe_id, p_issued_by, trim(p_receipt_reference), p_nfc_tag_id, p_cafe_id, p_verification_reference);

  insert into public.cafe_memberships(customer_id, cafe_id, stamps, updated_at)
  values (p_customer_id, p_cafe_id, 1, now())
  on conflict (customer_id, cafe_id) do update
  set stamps = public.cafe_memberships.stamps + 1, updated_at = now()
  returning stamps into v_count;

  update public.nfc_tags set last_used_at = now() where id = p_nfc_tag_id;
  return query select v_count, false;
end;
$function$;
revoke all on function public.issue_verified_stamp(uuid,uuid,uuid,text,uuid,text) from public, anon, authenticated;
grant execute on function public.issue_verified_stamp(uuid,uuid,uuid,text,uuid,text) to service_role;

-- Reward claim is likewise mediated by a trusted server endpoint after checking the customer session.
create or replace function public.claim_cafe_reward(
  p_customer_id uuid,
  p_cafe_id uuid
)
returns uuid
language plpgsql security definer set search_path = ''
as $function$
declare
  v_goal integer;
  v_title text;
  v_description text;
  v_current integer;
  v_claim_id uuid;
begin
  if auth.role() <> 'service_role' then raise exception 'Only the verified server endpoint may issue rewards'; end if;
  select stamps_required, reward_title, reward_description
    into v_goal, v_title, v_description
  from public.cafe_rewards where cafe_id = p_cafe_id and is_active;
  if v_goal is null then raise exception 'No active reward configured'; end if;
  if not exists (select 1 from public.profiles p where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved') then
    raise exception 'Customer account is not valid';
  end if;
  if not exists (select 1 from public.cafes c where c.id = p_cafe_id and c.is_active) then
    raise exception 'Cafe is not active';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_cafe_id::text, 0));
  select stamps into v_current from public.cafe_memberships
    where customer_id = p_customer_id and cafe_id = p_cafe_id for update;
  if coalesce(v_current, 0) < v_goal then raise exception 'Not enough stamps'; end if;
  update public.cafe_memberships set stamps = stamps - v_goal, updated_at = now()
    where customer_id = p_customer_id and cafe_id = p_cafe_id;
  insert into public.reward_claims(customer_id, cafe_id, stamps_spent, reward_snapshot)
    values (p_customer_id, p_cafe_id, v_goal, jsonb_build_object('title',v_title,'description',v_description))
    returning id into v_claim_id;
  return v_claim_id;
end;
$function$;
revoke all on function public.claim_cafe_reward(uuid,uuid) from public, anon, authenticated;
grant execute on function public.claim_cafe_reward(uuid,uuid) to service_role;


-- Employee access is branch-scoped. A NULL branch_id explicitly means all branches.
create or replace function public.can_access_cafe(target_cafe_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $access$
  select public.is_cafe_admin()
    or exists (
      select 1 from public.cafes c
      join public.profiles p on p.id = c.business_id
      where c.id = target_cafe_id and p.id = auth.uid()
        and p.role = 'business' and p.approval_status = 'approved'
    )
    or exists (
      select 1 from public.business_employees e
      join public.cafes c on c.business_id = e.business_id
      where c.id = target_cafe_id and e.employee_id = auth.uid()
        and e.is_active and (e.branch_id is null or e.branch_id = target_cafe_id)
    );
$access$;
revoke all on function public.can_access_cafe(uuid) from public;
grant execute on function public.can_access_cafe(uuid) to anon, authenticated;

drop policy if exists "memberships_read_business" on public.cafe_memberships;
create policy "memberships_read_business" on public.cafe_memberships for select to authenticated
using (public.can_access_cafe(cafe_id));

drop policy if exists "stamp_events_read_business" on public.stamp_events;
create policy "stamp_events_read_business" on public.stamp_events for select to authenticated
using (public.can_access_cafe(cafe_id));

drop policy if exists "cafe_rewards_read_active" on public.cafe_rewards;
create policy "cafe_rewards_read_active" on public.cafe_rewards for select to anon, authenticated
using (is_active or public.can_access_cafe(cafe_id));

drop policy if exists "business_employees_manage" on public.business_employees;
create policy "business_employees_manage" on public.business_employees for all to authenticated
using (
  (business_id = auth.uid() and exists (
    select 1 from public.profiles p where p.id = auth.uid()
      and p.role = 'business' and p.approval_status = 'approved'
  )) or public.is_cafe_admin()
)
with check (
  (
    business_id = auth.uid() and exists (
      select 1 from public.profiles p where p.id = auth.uid()
        and p.role = 'business' and p.approval_status = 'approved'
    ) and (
      branch_id is null or exists (
        select 1 from public.cafes c where c.id = branch_id and c.business_id = business_id
      )
    )
  ) or public.is_cafe_admin()
);
