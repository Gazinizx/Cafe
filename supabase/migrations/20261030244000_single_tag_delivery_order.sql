create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  if requested_role not in ('customer','business') then requested_role := 'customer'; end if;

  insert into public.profiles (id, full_name, email, role, approval_status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name',''),
    new.email,
    requested_role,
    case when requested_role = 'business' then 'pending' else 'approved' end
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

    -- Exactly one physical NFC tag is assigned per business; this row tracks its delivery only.
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
