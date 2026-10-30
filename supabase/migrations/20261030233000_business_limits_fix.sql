-- Tighten subscription limit triggers against business ownership reassignment.

create or replace function private.enforce_business_limits()
returns trigger
language plpgsql security definer set search_path = ''
as $limits$
declare
  v_business_id uuid;
  v_limit integer;
  v_count integer;
begin
  if auth.uid() is null or public.is_cafe_admin() then return new; end if;

  v_business_id := new.business_id;
  if v_business_id <> auth.uid() then raise exception 'Business ownership mismatch'; end if;
  if tg_op = 'UPDATE' and new.business_id <> old.business_id then
    raise exception 'Business ownership cannot be changed';
  end if;

  if tg_table_name = 'cafes' then
    if tg_op = 'UPDATE' and (not new.is_active or old.is_active) then return new; end if;
    select coalesce((
      select p.branch_limit
      from public.business_subscriptions s
      join public.subscription_packages p on p.id = s.package_id
      where s.business_id = v_business_id and s.status = 'active'
        and (s.ends_at is null or s.ends_at > now())
      order by s.ends_at desc nulls last limit 1
    ), 1) into v_limit;
    select count(*) into v_count from public.cafes c
      where c.business_id = v_business_id and (tg_op = 'INSERT' or c.id <> new.id);
    if v_count >= v_limit then raise exception 'Your subscription branch limit has been reached'; end if;
    return new;
  end if;

  if tg_table_name = 'business_employees' then
    if not new.is_active or (tg_op = 'UPDATE' and old.is_active) then return new; end if;
    select coalesce((
      select p.employee_limit
      from public.business_subscriptions s
      join public.subscription_packages p on p.id = s.package_id
      where s.business_id = v_business_id and s.status = 'active'
        and (s.ends_at is null or s.ends_at > now())
      order by s.ends_at desc nulls last limit 1
    ), 1) into v_limit;
    select count(*) into v_count from public.business_employees e
      where e.business_id = v_business_id and e.is_active
        and (tg_op = 'INSERT' or e.id <> new.id);
    if v_count >= v_limit then raise exception 'Your subscription employee limit has been reached'; end if;
    return new;
  end if;

  return new;
end;
$limits$;
