-- Redeem an issued reward once, after an authenticated business owner or assigned employee confirms handover.
create or replace function public.redeem_cafe_reward(
  p_claim_id uuid,
  p_redeemed_by uuid
)
returns uuid
language plpgsql security definer set search_path = ''
as $redeem$
declare
  v_business_id uuid;
  v_cafe_id uuid;
  v_status text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the verified server endpoint may redeem rewards';
  end if;

  select rc.status, rc.cafe_id, c.business_id
    into v_status, v_cafe_id, v_business_id
  from public.reward_claims rc
  join public.cafes c on c.id = rc.cafe_id
  where rc.id = p_claim_id
  for update of rc;

  if v_status is null then raise exception 'Reward claim not found'; end if;
  if v_status <> 'issued' then raise exception 'Reward claim is no longer available'; end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_redeemed_by and p.id = v_business_id
      and p.role = 'business' and p.approval_status = 'approved'
  ) and not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = p_redeemed_by
      and e.is_active and (e.branch_id is null or e.branch_id = v_cafe_id)
  ) then
    raise exception 'User is not authorized to redeem this reward';
  end if;

  update public.reward_claims
  set status = 'redeemed', redeemed_by = p_redeemed_by, redeemed_at = now()
  where id = p_claim_id and status = 'issued';

  if not found then raise exception 'Reward claim was already redeemed'; end if;
  return p_claim_id;
end;
$redeem$;

revoke all on function public.redeem_cafe_reward(uuid,uuid) from public, anon, authenticated;
grant execute on function public.redeem_cafe_reward(uuid,uuid) to service_role;
