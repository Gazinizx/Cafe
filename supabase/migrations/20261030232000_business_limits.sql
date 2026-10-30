-- Enforce subscription limits at the database boundary and prevent duplicate pending payment requests.

create or replace function private.enforce_business_limits()
returns trigger
language plpgsql security definer set search_path = ''
as $limits$
declare
  v_business_id uuid;
  v_limit integer;
  v_count integer;
begin
  -- Auth triggers and trusted server operations may not carry an end-user JWT.
  if auth.uid() is null or public.is_cafe_admin() then return new; end if;

  v_business_id := new.business_id;
  if v_business_id <> auth.uid() then raise exception 'Business ownership mismatch'; end if;

  if tg_table_name = 'cafes' then
    select coalesce((
      select p.branch_limit
      from public.business_subscriptions s
      join public.subscription_packages p on p.id = s.package_id
      where s.business_id = v_business_id and s.status = 'active'
        and (s.ends_at is null or s.ends_at > now())
      order by s.ends_at desc nulls last limit 1
    ), 1) into v_limit;

    if tg_op = 'UPDATE' and (not new.is_active or old.is_active) then return new; end if;
    select count(*) into v_count from public.cafes c
      where c.business_id = v_business_id and (tg_op = 'INSERT' or c.id <> new.id);
    if v_count >= v_limit then raise exception 'Your subscription branch limit has been reached'; end if;
    return new;
  end if;

  if tg_table_name = 'business_employees' then
    select coalesce((
      select p.employee_limit
      from public.business_subscriptions s
      join public.subscription_packages p on p.id = s.package_id
      where s.business_id = v_business_id and s.status = 'active'
        and (s.ends_at is null or s.ends_at > now())
      order by s.ends_at desc nulls last limit 1
    ), 1) into v_limit;

    if not new.is_active or (tg_op = 'UPDATE' and old.is_active) then return new; end if;
    select count(*) into v_count from public.business_employees e
      where e.business_id = v_business_id and e.is_active
        and (tg_op = 'INSERT' or e.id <> new.id);
    if v_count >= v_limit then raise exception 'Your subscription employee limit has been reached'; end if;
    return new;
  end if;

  return new;
end;
$limits$;
revoke all on function private.enforce_business_limits() from public, anon, authenticated;

drop trigger if exists enforce_cafe_branch_limit on public.cafes;
create trigger enforce_cafe_branch_limit
before insert or update of is_active, business_id on public.cafes
for each row execute function private.enforce_business_limits();

drop trigger if exists enforce_business_employee_limit on public.business_employees;
create trigger enforce_business_employee_limit
before insert or update of is_active, business_id on public.business_employees
for each row execute function private.enforce_business_limits();

drop policy if exists "cafes_owner_insert" on public.cafes;
create policy "cafes_owner_insert" on public.cafes for insert to authenticated with check (
  owner_id = (select auth.uid()) and business_id = (select auth.uid())
  and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'business' and p.approval_status = 'approved')
);

create unique index if not exists manual_payments_one_pending_business_idx
on public.manual_payments(business_id) where status = 'pending';
