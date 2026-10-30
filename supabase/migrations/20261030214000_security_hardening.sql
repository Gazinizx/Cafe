-- Cafe Dünyam security and query-planning hardening.
-- Keep business-owner and admin capabilities separate from read policies.

revoke all on function public.is_business_member(uuid) from public, anon, authenticated;
drop function if exists public.is_business_member(uuid);

revoke execute on function public.can_access_cafe(uuid) from anon;
grant execute on function public.can_access_cafe(uuid) to authenticated;

drop policy if exists "cafe_rewards_read_active" on public.cafe_rewards;
drop policy if exists "cafe_rewards_business_manage" on public.cafe_rewards;
create policy "cafe_rewards_public_read" on public.cafe_rewards for select to anon
using (is_active);
create policy "cafe_rewards_authenticated_read" on public.cafe_rewards for select to authenticated
using (is_active or public.can_access_cafe(cafe_id));
create policy "cafe_rewards_business_insert" on public.cafe_rewards for insert to authenticated
with check (exists (select 1 from public.cafes c where c.id = cafe_id and (c.business_id = (select auth.uid()) or public.is_cafe_admin())));
create policy "cafe_rewards_business_update" on public.cafe_rewards for update to authenticated
using (exists (select 1 from public.cafes c where c.id = cafe_id and (c.business_id = (select auth.uid()) or public.is_cafe_admin())))
with check (exists (select 1 from public.cafes c where c.id = cafe_id and (c.business_id = (select auth.uid()) or public.is_cafe_admin())));
create policy "cafe_rewards_business_delete" on public.cafe_rewards for delete to authenticated
using (exists (select 1 from public.cafes c where c.id = cafe_id and (c.business_id = (select auth.uid()) or public.is_cafe_admin())));

drop policy if exists "business_employees_manage" on public.business_employees;
create policy "business_employees_insert" on public.business_employees for insert to authenticated
with check (
  ((business_id = (select auth.uid())) and exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.role = 'business' and p.approval_status = 'approved'
  ) and (branch_id is null or exists (
    select 1 from public.cafes c where c.id = branch_id and c.business_id = business_id
  ))) or public.is_cafe_admin()
);
create policy "business_employees_update" on public.business_employees for update to authenticated
using (business_id = (select auth.uid()) or public.is_cafe_admin())
with check (
  ((business_id = (select auth.uid())) and exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.role = 'business' and p.approval_status = 'approved'
  ) and (branch_id is null or exists (
    select 1 from public.cafes c where c.id = branch_id and c.business_id = business_id
  ))) or public.is_cafe_admin()
);
create policy "business_employees_delete" on public.business_employees for delete to authenticated
using (business_id = (select auth.uid()) or public.is_cafe_admin());

drop policy if exists "nfc_tags_admin_manage" on public.nfc_tags;

drop policy if exists "subscription_packages_admin_manage" on public.subscription_packages;
create policy "subscription_packages_admin_insert" on public.subscription_packages for insert to authenticated
with check (public.is_cafe_admin());
create policy "subscription_packages_admin_update" on public.subscription_packages for update to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());
create policy "subscription_packages_admin_delete" on public.subscription_packages for delete to authenticated
using (public.is_cafe_admin());

drop policy if exists "business_subscriptions_admin_manage" on public.business_subscriptions;
create policy "business_subscriptions_admin_insert" on public.business_subscriptions for insert to authenticated
with check (public.is_cafe_admin());
create policy "business_subscriptions_admin_update" on public.business_subscriptions for update to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());
create policy "business_subscriptions_admin_delete" on public.business_subscriptions for delete to authenticated
using (public.is_cafe_admin());

drop policy if exists "manual_payments_admin_manage" on public.manual_payments;
create policy "manual_payments_admin_update" on public.manual_payments for update to authenticated
using (public.is_cafe_admin()) with check (public.is_cafe_admin());

-- Cover the new foreign keys and common business lookups.
create index if not exists business_employees_employee_idx on public.business_employees(employee_id, is_active);
create index if not exists business_employees_branch_idx on public.business_employees(branch_id);
create index if not exists business_orders_business_created_idx on public.business_orders(business_id, created_at desc);
create index if not exists stamp_events_nfc_tag_idx on public.stamp_events(nfc_tag_id);
create index if not exists stamp_events_branch_created_idx on public.stamp_events(branch_id, created_at desc);
create index if not exists reward_claims_cafe_created_idx on public.reward_claims(cafe_id, created_at desc);
create index if not exists reward_claims_redeemed_by_idx on public.reward_claims(redeemed_by);
create index if not exists business_subscriptions_package_idx on public.business_subscriptions(package_id);
create index if not exists manual_payments_subscription_idx on public.manual_payments(subscription_id);
create index if not exists manual_payments_received_by_idx on public.manual_payments(received_by);
create index if not exists cafes_owner_idx on public.cafes(owner_id);
