-- Package-linked manual collection and atomic admin confirmation.

alter table public.manual_payments
  add column if not exists package_id uuid references public.subscription_packages(id) on delete restrict;
create index if not exists manual_payments_package_idx on public.manual_payments(package_id);

create or replace function private.validate_manual_payment_request()
returns trigger
language plpgsql security definer set search_path = ''
as $validate$
declare
  v_price numeric(10,2);
  v_active boolean;
begin
  if auth.uid() is null or new.business_id <> auth.uid() then
    raise exception 'Payment request must belong to the signed-in business';
  end if;
  if new.status <> 'pending' or new.received_by is not null or new.paid_at is not null then
    raise exception 'A business can only submit a pending payment request';
  end if;
  if new.package_id is null then raise exception 'Select an active package'; end if;
  select p.price_try, p.is_active into v_price, v_active
  from public.subscription_packages p where p.id = new.package_id;
  if v_active is distinct from true then raise exception 'Package is not active'; end if;
  if new.amount_try <> v_price then raise exception 'Payment amount does not match the selected package'; end if;
  return new;
end;
$validate$;
revoke all on function private.validate_manual_payment_request() from public, anon, authenticated;

drop trigger if exists validate_manual_payment_request on public.manual_payments;
create trigger validate_manual_payment_request
before insert on public.manual_payments
for each row execute function private.validate_manual_payment_request();

create or replace function public.confirm_manual_payment(p_payment_id uuid)
returns uuid
language plpgsql
set search_path = ''
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
  if not public.is_cafe_admin() then raise exception 'Only an administrator can confirm payments'; end if;

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
