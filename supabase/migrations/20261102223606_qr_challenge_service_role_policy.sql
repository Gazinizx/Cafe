drop policy if exists campaign_qr_challenges_service_role_only on public.campaign_qr_challenges;
create policy campaign_qr_challenges_service_role_only
on public.campaign_qr_challenges
for all to service_role
using (true)
with check (true);
