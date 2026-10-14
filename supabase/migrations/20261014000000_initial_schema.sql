-- Cafe Dünyam cloud schema (Supabase / PostgreSQL)
-- Apply in Supabase SQL Editor. Client-side access is restricted by RLS.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null check (role in ('customer','business','admin')),
  approval_status text not null default 'pending'
    check (approval_status in ('pending','approved','rejected')),
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.cafes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  city text not null,
  district text,
  address text,
  category text,
  description text,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  title text not null,
  benefit text not null,
  audience text not null default 'Herkes',
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.cafe_memberships (
  customer_id uuid not null references public.profiles(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  stamps integer not null default 0 check (stamps >= 0),
  updated_at timestamptz not null default now(),
  primary key (customer_id, cafe_id)
);

create table if not exists public.stamp_events (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete restrict,
  cafe_id uuid not null references public.cafes(id) on delete restrict,
  issued_by uuid not null references public.profiles(id) on delete restrict,
  receipt_reference text not null,
  created_at timestamptz not null default now(),
  unique (cafe_id, receipt_reference)
);

create table if not exists public.business_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.profiles(id) on delete cascade,
  order_data jsonb not null default '{}'::jsonb,
  order_status text not null default 'pending',
  payment_status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.cafes enable row level security;
alter table public.campaigns enable row level security;
alter table public.cafe_memberships enable row level security;
alter table public.stamp_events enable row level security;
alter table public.business_orders enable row level security;

-- Profiles: users can read/update their own profile; admin operations belong in trusted server tooling.
create policy "profiles_read_self" on public.profiles for select to authenticated using (id = auth.uid());
-- Profile creation is handled by the trusted auth.users trigger. Clients cannot change roles or approval status.
-- Keep profile writes unavailable to client sessions to prevent self-approval or privilege escalation.

-- Public users may see active cafes and campaigns. Only an approved owner may manage their cafe.
create policy "cafes_read_active" on public.cafes for select to anon, authenticated using (is_active = true or owner_id = auth.uid());
create policy "cafes_owner_insert" on public.cafes for insert to authenticated with check (
  owner_id = auth.uid() and exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'business' and p.approval_status = 'approved'
  )
);
create policy "cafes_owner_update" on public.cafes for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "campaigns_read_active" on public.campaigns for select to anon, authenticated using (
  is_active = true or exists (select 1 from public.cafes c where c.id = cafe_id and c.owner_id = auth.uid())
);
create policy "campaigns_owner_insert" on public.campaigns for insert to authenticated with check (
  exists (select 1 from public.cafes c join public.profiles p on p.id = c.owner_id
    where c.id = cafe_id and c.owner_id = auth.uid() and p.approval_status = 'approved')
);
create policy "campaigns_owner_update" on public.campaigns for update to authenticated using (
  exists (select 1 from public.cafes c where c.id = cafe_id and c.owner_id = auth.uid())
) with check (
  exists (select 1 from public.cafes c where c.id = cafe_id and c.owner_id = auth.uid())
);

-- Customers can read their own balances and event history. Clients cannot directly write stamps.
create policy "memberships_read_self" on public.cafe_memberships for select to authenticated using (customer_id = auth.uid());
create policy "stamp_events_read_participant" on public.stamp_events for select to authenticated using (
  customer_id = auth.uid() or issued_by = auth.uid()
);
create policy "orders_read_owner" on public.business_orders for select to authenticated using (business_id = auth.uid());
create policy "orders_insert_owner" on public.business_orders for insert to authenticated with check (business_id = auth.uid());

-- Create a profile after signup. Role comes from user metadata but admin is never allowed from client metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  if requested_role not in ('customer','business') then requested_role := 'customer'; end if;
  insert into public.profiles (id, full_name, role, approval_status)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name',''), requested_role,
          case when requested_role = 'business' then 'pending' else 'approved' end);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create index if not exists cafes_city_active_idx on public.cafes(city, is_active);
create index if not exists campaigns_cafe_active_idx on public.campaigns(cafe_id, is_active);
create index if not exists stamp_events_customer_created_idx on public.stamp_events(customer_id, created_at desc);
