-- Allow approved Cafe Dunyam administrators to create campaigns for any active branch.
drop policy if exists campaigns_admin_insert on public.campaigns;
create policy campaigns_admin_insert
on public.campaigns
for insert
to authenticated
with check (private.is_cafe_admin());
