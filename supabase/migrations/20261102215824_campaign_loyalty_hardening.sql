-- Performance and policy cleanup for campaign loyalty tables.
create index if not exists campaign_memberships_campaign_idx on public.campaign_memberships(campaign_id);
create index if not exists campaign_stamp_events_cafe_idx on public.campaign_stamp_events(cafe_id);
create index if not exists campaign_stamp_events_customer_idx on public.campaign_stamp_events(customer_id);
create index if not exists campaign_stamp_events_issued_by_idx on public.campaign_stamp_events(issued_by);
create index if not exists campaigns_stamp_icon_idx on public.campaigns(stamp_icon);
create index if not exists reward_claims_campaign_idx on public.reward_claims(campaign_id);

drop policy if exists campaign_stamp_icons_admin_manage on public.campaign_stamp_icons;
drop policy if exists campaign_stamp_icons_admin_insert on public.campaign_stamp_icons;
create policy campaign_stamp_icons_admin_insert on public.campaign_stamp_icons
for insert to authenticated with check (private.is_cafe_admin());

drop policy if exists campaign_stamp_icons_admin_update on public.campaign_stamp_icons;
create policy campaign_stamp_icons_admin_update on public.campaign_stamp_icons
for update to authenticated using (private.is_cafe_admin()) with check (private.is_cafe_admin());

drop policy if exists campaign_stamp_icons_admin_delete on public.campaign_stamp_icons;
create policy campaign_stamp_icons_admin_delete on public.campaign_stamp_icons
for delete to authenticated using (private.is_cafe_admin());
