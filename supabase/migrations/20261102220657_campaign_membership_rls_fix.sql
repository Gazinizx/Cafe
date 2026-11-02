-- Allow approved customers to join campaigns without exposing other profiles.
create or replace function private.is_approved_business(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1 from public.profiles p
    where p.id = target_business_id
      and p.role = 'business'
      and p.approval_status = 'approved'
  );
$function$;

revoke all on function private.is_approved_business(uuid) from public, anon;
grant execute on function private.is_approved_business(uuid) to authenticated;

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
      and private.is_approved_business(f.business_id)
  )
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'customer' and p.approval_status = 'approved'
  )
);
