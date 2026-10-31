-- Allow approved Cafe Dünyam administrators to create campaigns for any active branch.
create policy campaigns_admin_insert
on public.campaigns
for insert
to authenticated
with check (private.is_cafe_admin());
