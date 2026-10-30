-- Correct branch ownership correlation, split public package reads, and index remaining foreign keys.

drop policy if exists "business_employees_insert" on public.business_employees;
create policy "business_employees_insert" on public.business_employees for insert to authenticated
with check (
  ((business_id = (select auth.uid())) and exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.role = 'business' and p.approval_status = 'approved'
  ) and (branch_id is null or exists (
    select 1 from public.cafes c
    where c.id = branch_id and c.business_id = business_employees.business_id
  ))) or public.is_cafe_admin()
);

drop policy if exists "business_employees_update" on public.business_employees;
create policy "business_employees_update" on public.business_employees for update to authenticated
using (business_id = (select auth.uid()) or public.is_cafe_admin())
with check (
  ((business_id = (select auth.uid())) and exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
      and p.role = 'business' and p.approval_status = 'approved'
  ) and (branch_id is null or exists (
    select 1 from public.cafes c
    where c.id = branch_id and c.business_id = business_employees.business_id
  ))) or public.is_cafe_admin()
);

drop policy if exists "subscription_packages_read_active" on public.subscription_packages;
create policy "subscription_packages_public_read" on public.subscription_packages for select to anon
using (is_active);
create policy "subscription_packages_authenticated_read" on public.subscription_packages for select to authenticated
using (is_active or public.is_cafe_admin());

create index if not exists cafe_memberships_cafe_customer_idx on public.cafe_memberships(cafe_id, customer_id);
create index if not exists reward_claims_customer_idx on public.reward_claims(customer_id);
create index if not exists saved_campaigns_campaign_idx on public.saved_campaigns(campaign_id);
create index if not exists stamp_events_issued_by_idx on public.stamp_events(issued_by);
