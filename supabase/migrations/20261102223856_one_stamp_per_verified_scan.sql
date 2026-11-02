-- Every verified NFC or one-time QR scan can award one campaign stamp; replay protection remains at each channel.
CREATE OR REPLACE FUNCTION public.issue_campaign_qr_stamp(p_token_hash text, p_campaign_id uuid, p_customer_id uuid)
 RETURNS TABLE(new_stamp_count integer, duplicate_blocked boolean, reward_ready boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_business_id uuid;
  v_branch_id uuid;
  v_issued_by uuid;
  v_campaign_business uuid;
  v_goal integer;
  v_current integer;
begin
  if (auth.jwt() ->> 'role') <> 'service_role' then
    raise exception 'Only the verified server endpoint may issue QR stamps';
  end if;
  if p_token_hash is null or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid QR token';
  end if;

  select q.business_id, q.branch_id, q.issued_by
    into v_business_id, v_branch_id, v_issued_by
  from public.campaign_qr_challenges q
  where q.token_hash = p_token_hash
    and q.consumed_at is null
    and q.expires_at > now()
  for update;
  if v_business_id is null then raise exception 'QR code expired or already used'; end if;

  if not exists (
    select 1 from public.cafes f
    where f.id = v_branch_id and f.business_id = v_business_id and f.is_active
  ) then raise exception 'QR branch is no longer active'; end if;

  select f.business_id, c.stamps_required
    into v_campaign_business, v_goal
  from public.campaigns c
  join public.cafes f on f.id = c.cafe_id
  where c.id = p_campaign_id and c.is_active
    and (c.starts_at is null or c.starts_at <= now())
    and (c.ends_at is null or c.ends_at > now());
  if v_campaign_business is null then raise exception 'Campaign is not active'; end if;
  if v_campaign_business <> v_business_id then
    raise exception 'QR code and selected campaign belong to different businesses';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved'
  ) then raise exception 'Customer account is not valid'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_business_id and p.role = 'business' and p.approval_status = 'approved'
  ) then raise exception 'Business account is not approved'; end if;
  if v_issued_by <> v_business_id and not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = v_issued_by
      and e.is_active and (e.branch_id is null or e.branch_id = v_branch_id)
  ) then raise exception 'QR issuer is no longer authorized'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_campaign_id::text, 0));
  if not exists (
    select 1 from public.campaign_memberships m
    where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  ) then raise exception 'Customer has not joined this campaign'; end if;

  update public.campaign_qr_challenges
    set consumed_at = now()
  where token_hash = p_token_hash and consumed_at is null;

  select m.stamps into v_current
  from public.campaign_memberships m
  where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  for update;

  if coalesce(v_current, 0) >= v_goal then
    return query select coalesce(v_current, 0), false, true;
    return;
  end if;

  insert into public.campaign_stamp_events(
    customer_id, campaign_id, cafe_id, issued_by, nfc_tag_id, read_counter,
    receipt_reference, verification_reference
  ) values (
    p_customer_id, p_campaign_id, v_branch_id, v_issued_by, null, null,
    'QR:' || substr(p_token_hash, 1, 32), p_token_hash
  );

  update public.campaign_memberships
    set stamps = stamps + 1, updated_at = now()
  where customer_id = p_customer_id and campaign_id = p_campaign_id
  returning stamps into v_current;

  return query select v_current, false, v_current >= v_goal;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.issue_verified_campaign_stamp(p_customer_id uuid, p_campaign_id uuid, p_issued_by uuid, p_receipt_reference text, p_nfc_tag_id uuid, p_verification_reference text, p_read_counter bigint)
 RETURNS TABLE(new_stamp_count integer, duplicate_blocked boolean, reward_ready boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_business_id uuid;
  v_branch_id uuid;
  v_last_counter bigint;
  v_campaign_business uuid;
  v_goal integer;
  v_current integer;
begin
  if auth.role() <> 'service_role' then raise exception 'Only the verified server endpoint may issue stamps'; end if;
  if p_read_counter < 0 or p_read_counter > 16777215 then raise exception 'Invalid NFC read counter'; end if;
  if p_receipt_reference is null or length(trim(p_receipt_reference)) < 8 then raise exception 'Invalid transaction reference'; end if;
  if p_verification_reference is null or length(trim(p_verification_reference)) < 8 then raise exception 'Missing NFC verification reference'; end if;

  select t.business_id, t.branch_id, t.last_read_counter
    into v_business_id, v_branch_id, v_last_counter
  from public.nfc_tags t
  where t.id = p_nfc_tag_id and t.status = 'active'
  for update;
  if v_business_id is null then raise exception 'NFC tag is not active'; end if;
  if p_read_counter <= v_last_counter then raise exception 'NFC replay detected'; end if;

  if v_branch_id is null then
    select f.id into v_branch_id
    from public.cafes f
    where f.business_id = v_business_id and f.is_active
    order by f.is_main_branch desc, f.created_at, f.id
    limit 1;
  end if;
  if v_branch_id is null or not exists (
    select 1 from public.cafes f
    where f.id = v_branch_id and f.business_id = v_business_id and f.is_active
  ) then raise exception 'No active branch is assigned to this NFC tag'; end if;

  select f.business_id, c.stamps_required
    into v_campaign_business, v_goal
  from public.campaigns c
  join public.cafes f on f.id = c.cafe_id
  where c.id = p_campaign_id and c.is_active
    and (c.starts_at is null or c.starts_at <= now())
    and (c.ends_at is null or c.ends_at > now());
  if v_campaign_business is null then raise exception 'Campaign is not active'; end if;
  if v_campaign_business <> v_business_id then raise exception 'NFC tag and selected campaign belong to different businesses'; end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_customer_id and p.role = 'customer' and p.approval_status = 'approved'
  ) then raise exception 'Customer account is not valid'; end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = v_business_id and p.role = 'business' and p.approval_status = 'approved'
  ) then raise exception 'Business account is not approved'; end if;
  if p_issued_by <> v_business_id and not exists (
    select 1 from public.business_employees e
    where e.business_id = v_business_id and e.employee_id = p_issued_by
      and e.is_active and (e.branch_id is null or e.branch_id = v_branch_id)
  ) then raise exception 'Employee is not authorized for this business'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || p_campaign_id::text, 0));
  update public.nfc_tags
  set last_read_counter = p_read_counter, last_used_at = now()
  where id = p_nfc_tag_id;

  if not exists (
    select 1 from public.campaign_memberships m
    where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  ) then raise exception 'Customer has not joined this campaign'; end if;

  select m.stamps into v_current
  from public.campaign_memberships m
  where m.customer_id = p_customer_id and m.campaign_id = p_campaign_id
  for update;

  if coalesce(v_current, 0) >= v_goal then
    return query select coalesce(v_current, 0), false, true;
    return;
  end if;

  insert into public.campaign_stamp_events(
    customer_id,campaign_id,cafe_id,issued_by,nfc_tag_id,read_counter,receipt_reference,verification_reference
  ) values (
    p_customer_id,p_campaign_id,v_branch_id,p_issued_by,p_nfc_tag_id,p_read_counter,
    trim(p_receipt_reference),trim(p_verification_reference)
  );

  update public.campaign_memberships
  set stamps = stamps + 1, updated_at = now()
  where customer_id = p_customer_id and campaign_id = p_campaign_id
  returning stamps into v_current;

  return query select v_current, false, v_current >= v_goal;
end;
$function$

