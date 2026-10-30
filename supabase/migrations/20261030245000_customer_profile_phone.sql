-- Keep the live Auth profile phone behavior reproducible from source control.
-- This function definition matches the currently deployed Cafe Dünyam database.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  if requested_role not in ('customer','business') then requested_role := 'customer'; end if;

  insert into public.profiles (id, full_name, email, role, approval_status, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name',''),
    new.email,
    requested_role,
    case when requested_role = 'business' then 'pending' else 'approved' end,
    nullif(new.raw_user_meta_data ->> 'phone','')
  );

  if requested_role = 'business' then
    insert into public.business_applications (
      business_id, cafe_name, phone, business_type, tax_office, tax_number,
      province, district, business_address, delivery_name, delivery_phone,
      delivery_province, delivery_district, delivery_address, tag_count
    ) values (
      new.id,
      coalesce(new.raw_user_meta_data ->> 'cafe_name','İşletme'),
      new.raw_user_meta_data ->> 'phone',
      new.raw_user_meta_data ->> 'business_type',
      new.raw_user_meta_data ->> 'tax_office',
      new.raw_user_meta_data ->> 'tax_number',
      new.raw_user_meta_data ->> 'province',
      new.raw_user_meta_data ->> 'district',
      new.raw_user_meta_data ->> 'business_address',
      new.raw_user_meta_data ->> 'delivery_name',
      new.raw_user_meta_data ->> 'delivery_phone',
      new.raw_user_meta_data ->> 'delivery_province',
      new.raw_user_meta_data ->> 'delivery_district',
      new.raw_user_meta_data ->> 'delivery_address',
      1
    );

    insert into public.cafes (owner_id, business_id, name, city, district, address, category, is_active)
    values (
      new.id, new.id,
      coalesce(new.raw_user_meta_data ->> 'cafe_name','İşletme'),
      coalesce(new.raw_user_meta_data ->> 'province',''),
      new.raw_user_meta_data ->> 'district',
      new.raw_user_meta_data ->> 'business_address',
      new.raw_user_meta_data ->> 'business_type',
      false
    );

    insert into public.business_orders (business_id, order_data, order_status, payment_status)
    values (
      new.id,
      jsonb_build_object(
        'businessName', coalesce(new.raw_user_meta_data ->> 'cafe_name','İşletme'),
        'tagCount', 1,
        'orderStatus', 'İncelemede',
        'recipientName', new.raw_user_meta_data ->> 'delivery_name',
        'recipientPhone', new.raw_user_meta_data ->> 'delivery_phone',
        'province', new.raw_user_meta_data ->> 'delivery_province',
        'district', new.raw_user_meta_data ->> 'delivery_district',
        'address', new.raw_user_meta_data ->> 'delivery_address',
        'createdAt', now()
      ),
      'pending',
      'pending'
    );
  end if;
  return new;
end;
$function$;

-- Backfill phone numbers for accounts created before the profile trigger stored them.
update public.profiles as p
set phone = nullif(btrim(u.raw_user_meta_data ->> 'phone'), '')
from auth.users as u
where p.id = u.id
  and (p.phone is null or btrim(p.phone) = '')
  and nullif(btrim(u.raw_user_meta_data ->> 'phone'), '') is not null;
