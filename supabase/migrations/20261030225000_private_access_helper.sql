-- Move the RLS-only business access helper out of the exposed public API schema.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.can_access_cafe(target_cafe_id uuid)
returns boolean
language sql stable security definer set search_path = ''
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
revoke all on function private.can_access_cafe(uuid) from public, anon;
grant execute on function private.can_access_cafe(uuid) to authenticated;

drop policy if exists "memberships_read_business" on public.cafe_memberships;
create policy "memberships_read_business" on public.cafe_memberships for select to authenticated
using (private.can_access_cafe(cafe_id));

drop policy if exists "stamp_events_read_business" on public.stamp_events;
create policy "stamp_events_read_business" on public.stamp_events for select to authenticated
using (private.can_access_cafe(cafe_id));

drop policy if exists "cafe_rewards_authenticated_read" on public.cafe_rewards;
create policy "cafe_rewards_authenticated_read" on public.cafe_rewards for select to authenticated
using (is_active or private.can_access_cafe(cafe_id));

drop policy if exists "reward_claims_read_participant" on public.reward_claims;
create policy "reward_claims_read_participant" on public.reward_claims for select to authenticated
using (customer_id = (select auth.uid()) or private.can_access_cafe(cafe_id));

revoke all on function public.can_access_cafe(uuid) from public, anon, authenticated;
drop function public.can_access_cafe(uuid);
