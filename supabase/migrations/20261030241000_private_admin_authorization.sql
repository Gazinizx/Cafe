-- Keep security-definer authorization helpers out of the exposed public API schema.

create or replace function private.is_cafe_admin()
returns boolean
language sql stable security definer set search_path = ''
as $admin$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and approval_status = 'approved'
  );
$admin$;
revoke all on function private.is_cafe_admin() from public, anon;
grant execute on function private.is_cafe_admin() to authenticated;

-- Rewrite all RLS policies that used the public helper.
do $policies$
declare
  p record;
  v_sql text;
  v_roles text;
begin
  for p in
    select schemaname, tablename, policyname, permissive, cmd, roles, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') like '%is_cafe_admin()%'
        or coalesce(with_check, '') like '%is_cafe_admin()%')
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    v_roles := array_to_string(p.roles, ', ');
    v_sql := format('create policy %I on %I.%I as %s for %s to %s',
      p.policyname, p.schemaname, p.tablename, p.permissive, p.cmd, v_roles);
    if p.qual is not null then
      v_sql := v_sql || ' using (' || replace(p.qual, 'is_cafe_admin()', 'private.is_cafe_admin()') || ')';
    end if;
    if p.with_check is not null then
      v_sql := v_sql || ' with check (' || replace(p.with_check, 'is_cafe_admin()', 'private.is_cafe_admin()') || ')';
    end if;
    execute v_sql;
  end loop;
end;
$policies$;

create or replace function private.can_access_cafe(target_cafe_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $access$
  select private.is_cafe_admin()
    or exists (
      select 1 from public.cafes c
      join public.profiles p on p.id = c.business_id
      where c.id = target_cafe_id and p.id = auth.uid()
        and p.role = 'business' and p.approval_status = 'approved'
    )
    or exists (
      select 1 from public.business_employees e
      join public.cafes c on c.business_id = e.business_id
      where c.id = target_cafe_id and e.employee_id = auth.uid()
        and e.is_active and (e.branch_id is null or e.branch_id = target_cafe_id)
    );
$access$;

create or replace function private.enforce_business_limits()
returns trigger
language plpgsql security definer set search_path = ''
as $limits$
declare
  v_business_id uuid;
  v_limit integer;
  v_count integer;
begin
  if auth.uid() is null or private.is_cafe_admin() then return new; end if;
  v_business_id := new.business_id;
  if v_business_id <> auth.uid() then raise exception 'Business ownership mismatch'; end if;
  if tg_op = 'UPDATE' and new.business_id <> old.business_id then
    raise exception 'Business ownership cannot be changed';
  end if;

  if tg_table_name = 'cafes' then
    if tg_op = 'UPDATE' and (not new.is_active or old.is_active) then return new; end if;
    select coalesce((
      select p.branch_limit from public.business_subscriptions s
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
      select p.employee_limit from public.business_subscriptions s
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

create or replace function public.confirm_manual_payment(p_payment_id uuid)
returns uuid
language plpgsql set search_path = ''
as $confirm$
declare
  v_business_id uuid;
  v_package_id uuid;
  v_status text;
  v_price_period text;
  v_existing_end timestamptz;
  v_start timestamptz;
  v_end timestamptz;
  v_subscription_id uuid;
begin
  if not private.is_cafe_admin() then raise exception 'Only an administrator can confirm payments'; end if;
  select mp.business_id, mp.package_id, mp.status, sp.billing_period
    into v_business_id, v_package_id, v_status, v_price_period
  from public.manual_payments mp
  join public.subscription_packages sp on sp.id = mp.package_id
  where mp.id = p_payment_id
  for update of mp;
  if v_status is null then raise exception 'Payment request not found'; end if;
  if v_status <> 'pending' then raise exception 'Payment request is no longer pending'; end if;
  select max(s.ends_at) into v_existing_end
  from public.business_subscriptions s
  where s.business_id = v_business_id and s.status = 'active';
  v_start := greatest(now(), coalesce(v_existing_end, now()));
  v_end := case when v_price_period = 'yearly' then v_start + interval '1 year'
                else v_start + interval '1 month' end;
  insert into public.business_subscriptions(
    business_id, package_id, status, starts_at, ends_at, payment_note
  ) values (
    v_business_id, v_package_id, 'active', v_start, v_end, 'Manuel tahsilat yönetici tarafından doğrulandı.'
  ) returning id into v_subscription_id;
  update public.manual_payments
  set status = 'confirmed', received_by = auth.uid(), paid_at = now(), subscription_id = v_subscription_id
  where id = p_payment_id and status = 'pending';
  if not found then raise exception 'Payment request was already processed'; end if;
  return v_subscription_id;
end;
$confirm$;

revoke all on function public.confirm_manual_payment(uuid) from public, anon;
grant execute on function public.confirm_manual_payment(uuid) to authenticated;

revoke all on function public.admin_delete_user(uuid) from public, anon, authenticated, service_role;
drop function public.admin_delete_user(uuid);
revoke all on function public.is_cafe_admin() from public, anon, authenticated;
drop function public.is_cafe_admin();
