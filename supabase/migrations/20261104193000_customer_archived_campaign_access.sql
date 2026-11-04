-- Allow customers to read the archived campaigns they previously joined.
-- This preserves card history while keeping unrelated inactive campaigns hidden.
create or replace function private.is_campaign_member(p_campaign_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.campaign_memberships m
    where m.campaign_id = p_campaign_id
      and m.customer_id = (select auth.uid())
  );
$function$;

revoke all on function private.is_campaign_member(uuid) from public, anon;
grant execute on function private.is_campaign_member(uuid) to authenticated;

drop policy if exists campaigns_read_active on public.campaigns;
create policy campaigns_read_active on public.campaigns
for select to anon, authenticated
using (
  is_active = true
  or exists (
    select 1 from public.cafes c
    where c.id = campaigns.cafe_id
      and c.owner_id = (select auth.uid())
  )
  or private.is_cafe_admin()
  or (select private.is_campaign_member(campaigns.id))
);
