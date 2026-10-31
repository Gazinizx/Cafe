create or replace function public.set_business_application_status(
  p_business_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_cafe_admin() then
    raise exception 'Bu işlem yalnızca sistem yöneticisine açıktır.';
  end if;
  if p_business_id is null or p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Geçersiz işletme veya başvuru durumu.';
  end if;
  if not exists (select 1 from public.profiles where id = p_business_id and role = 'business') then
    raise exception 'İşletme hesabı bulunamadı.';
  end if;

  update public.profiles
     set approval_status = p_status
   where id = p_business_id;

  update public.business_applications
     set application_status = p_status
   where business_id = p_business_id;

  update public.cafes
     set is_active = (p_status = 'approved')
   where business_id = p_business_id or owner_id = p_business_id;

  update public.business_orders
     set order_status = case
       when p_status = 'approved' then 'Etiket hazırlanıyor'
       when p_status = 'rejected' then 'Başvuru reddedildi'
       else 'İncelemede'
     end
   where business_id = p_business_id;
end;
$$;

revoke all on function public.set_business_application_status(uuid, text) from public, anon;
grant execute on function public.set_business_application_status(uuid, text) to authenticated;
