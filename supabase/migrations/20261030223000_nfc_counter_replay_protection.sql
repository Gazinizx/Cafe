-- Secure Dynamic Messaging counter enforcement for one NTAG 424 DNA per business.

alter table public.nfc_tags
  add column if not exists branch_id uuid references public.cafes(id) on delete restrict,
  add column if not exists last_read_counter bigint not null default -1
    check (last_read_counter between -1 and 16777215);

create index if not exists nfc_tags_branch_idx on public.nfc_tags(branch_id);

update public.nfc_tags t
set branch_id = (
  select c.id from public.cafes c
  where c.business_id = t.business_id
  order by c.is_main_branch desc, c.created_at, c.id
  limit 1
)
where t.branch_id is null;

drop function if exists public.issue_verified_stamp(uuid,uuid,uuid,text,uuid,text);

create or replace function public.issue_verified_stamp(
  p_customer_id uuid,
  p_cafe_id uuid,
  p_issued_by uuid,
  p_receipt_reference text,
  p_nfc_tag_id uuid,
  p_verification_reference text,
  p_read_counter bigint
)
returns table(new_stamp_count integer, duplicate_blocked boolean)
language plpgsql security definer set search_path = ''
as $stamp$
declare
  v_business_id uuid;
  v_branch_id uuid;
  v_last_counter bigint;
  v_count integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the verified server endpoint may issue stamps';
  end if;
  if p_read_counter < 0 or p_read_counter > 16777215 then
    raise exception 'Invalid NFC read counter';
  end if;
  if p_receipt_reference is null or length(trim(p_receipt_reference)) < 8 then
    raise exception 'Invalid transaction reference';
  end if;
  if p_verification_reference is null or length(trim(p_verification_reference)) < 8 then
    raise exception 'Missing NFC verification reference';
  end if;

  select t.business_id, t.branch_id, t.last_read_counter
    into v_business_id, v_branch_id, v_last_counter
  from public.nfc_tags t
  where t.id = p_nfc_tag_id and t.status = 'active'
  for update;
  if v_business_id is null then raise exception 'NFC tag is not active'; end if;
  if p_read_counter <= v_last_counter then raise exception 'NFC replay detected'; end if;

  if v_branch_id is null then
    select c.id into v_branch_id
    from public.cafes c
    where c.business_id = v_business_id and c.is_active
    order by c.is_main_branch desc, c.created_at, c.id
    limit 1;
  end if;
  if v_branch_id is null or not exists (
    select 1 from public.cafes c
    where c.id = v_branch_id and c.business_id = v_business_id and c.is_active
  ) then
    raise exception 'No active branch is assigned to this NFC tag';
  end if;
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

  -- Consume every cryptographically valid counter, including taps blocked by the 10-minute rule.
  update public.nfc_tags
  set last_read_counter = p_read_counter, last_used_at = now()
  where id = p_nfc_tag_id;

  perform pg_advisory_xact_lock(hashtextextended(p_customer_id::text || ':' || v_business_id::text, 0));
  if exists (
    select 1
    from public.stamp_events e
    join public.cafes c on c.id = e.cafe_id
    where e.customer_id = p_customer_id
      and c.business_id = v_business_id
      and e.created_at > now() - interval '10 minutes'
  ) then
    return query
      select coalesce((
        select m.stamps from public.cafe_memberships m
        where m.customer_id = p_customer_id and m.cafe_id = v_branch_id
      ), 0), true;
    return;
  end if;

  insert into public.stamp_events(
    customer_id, cafe_id, issued_by, receipt_reference,
    nfc_tag_id, branch_id, verification_reference
  ) values (
    p_customer_id, v_branch_id, p_issued_by, trim(p_receipt_reference),
    p_nfc_tag_id, v_branch_id, trim(p_verification_reference)
  );

  insert into public.cafe_memberships(customer_id, cafe_id, stamps, updated_at)
  values (p_customer_id, v_branch_id, 1, now())
  on conflict (customer_id, cafe_id) do update
  set stamps = public.cafe_memberships.stamps + 1, updated_at = now()
  returning stamps into v_count;

  return query select v_count, false;
end;
$stamp$;

revoke all on function public.issue_verified_stamp(uuid,uuid,uuid,text,uuid,text,bigint) from public, anon, authenticated;
grant execute on function public.issue_verified_stamp(uuid,uuid,uuid,text,uuid,text,bigint) to service_role;
