-- Consolidate overlapping admin/owner/participant SELECT/UPDATE/DELETE policies.

drop policy if exists orders_read_admin on public.business_orders;
drop policy if exists orders_read_owner on public.business_orders;
create policy orders_read_combined on public.business_orders for select to authenticated
using (private.is_cafe_admin() or business_id = (select auth.uid()));

drop policy if exists memberships_read_business on public.cafe_memberships;
drop policy if exists memberships_read_self on public.cafe_memberships;
create policy memberships_read_combined on public.cafe_memberships for select to authenticated
using (private.can_access_cafe(cafe_id) or customer_id = (select auth.uid()));

drop policy if exists cafes_admin_read on public.cafes;
drop policy if exists cafes_read_active on public.cafes;
create policy cafes_read_public on public.cafes for select to anon
using (is_active = true);
create policy cafes_read_authenticated on public.cafes for select to authenticated
using (is_active = true or owner_id = (select auth.uid()) or private.is_cafe_admin());

drop policy if exists cafes_admin_update on public.cafes;
drop policy if exists cafes_owner_update on public.cafes;
create policy cafes_update_authorized on public.cafes for update to authenticated
using (
  private.is_cafe_admin()
  or (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.approval_status = 'approved'
    )
  )
)
with check (
  private.is_cafe_admin()
  or (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.approval_status = 'approved'
    )
  )
);

drop policy if exists campaigns_admin_delete on public.campaigns;
drop policy if exists campaigns_owner_delete on public.campaigns;
create policy campaigns_delete_authorized on public.campaigns for delete to authenticated
using (
  private.is_cafe_admin()
  or exists (
    select 1 from public.cafes c
    where c.id = campaigns.cafe_id and c.owner_id = (select auth.uid())
  )
);

drop policy if exists campaigns_admin_update on public.campaigns;
drop policy if exists campaigns_owner_update on public.campaigns;
create policy campaigns_update_authorized on public.campaigns for update to authenticated
using (
  private.is_cafe_admin()
  or exists (
    select 1 from public.cafes c
    join public.profiles p on p.id = c.owner_id
    where c.id = campaigns.cafe_id and c.owner_id = (select auth.uid())
      and p.approval_status = 'approved'
  )
)
with check (
  private.is_cafe_admin()
  or exists (
    select 1 from public.cafes c
    join public.profiles p on p.id = c.owner_id
    where c.id = campaigns.cafe_id and c.owner_id = (select auth.uid())
      and p.approval_status = 'approved'
  )
);

drop policy if exists profiles_read_admin on public.profiles;
drop policy if exists profiles_read_self on public.profiles;
create policy profiles_read_authorized on public.profiles for select to authenticated
using (private.is_cafe_admin() or id = (select auth.uid()));

drop policy if exists stamp_events_read_business on public.stamp_events;
drop policy if exists stamp_events_read_participant on public.stamp_events;
create policy stamp_events_read_authorized on public.stamp_events for select to authenticated
using (
  private.can_access_cafe(cafe_id)
  or customer_id = (select auth.uid())
  or issued_by = (select auth.uid())
);
