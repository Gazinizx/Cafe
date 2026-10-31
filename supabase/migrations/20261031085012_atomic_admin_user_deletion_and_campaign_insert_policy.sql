create or replace function public.admin_delete_user(p_target_id uuid, p_actor_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cafe_ids uuid[];
begin
  if p_target_id is null or p_actor_id is null or p_target_id = p_actor_id then
    raise exception 'Geçersiz hedef kullanıcı.';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_actor_id and role = 'admin' and approval_status = 'approved'
  ) then
    raise exception 'Bu işlem yalnızca onaylı sistem yöneticisine açıktır.';
  end if;

  if not exists (select 1 from public.profiles where id = p_target_id)
     or exists (select 1 from public.profiles where id = p_target_id and role = 'admin') then
    raise exception 'Kullanıcı bulunamadı veya yönetici hesabı korunuyor.';
  end if;

  select coalesce(array_agg(id), '{}'::uuid[])
    into v_cafe_ids
  from public.cafes
  where owner_id = p_target_id or business_id = p_target_id;

  delete from public.stamp_events
   where customer_id = p_target_id
      or issued_by = p_target_id
      or cafe_id = any(v_cafe_ids)
      or branch_id = any(v_cafe_ids);

  delete from public.reward_claims
   where customer_id = p_target_id
      or cafe_id = any(v_cafe_ids);

  delete from public.nfc_tags
   where business_id = p_target_id
      or branch_id = any(v_cafe_ids);

  delete from public.cafes
   where owner_id = p_target_id or business_id = p_target_id;

  delete from auth.users where id = p_target_id;
  if not found then
    raise exception 'Kimlik hesabı silinemedi.';
  end if;
end;
$$;

revoke all on function public.admin_delete_user(uuid, uuid) from public, anon, authenticated;
grant execute on function public.admin_delete_user(uuid, uuid) to service_role;

drop policy if exists campaigns_admin_insert on public.campaigns;
drop policy if exists campaigns_owner_insert on public.campaigns;
create policy campaigns_insert_authorized
on public.campaigns
for insert
to authenticated
with check (
  private.is_cafe_admin()
  or exists (
    select 1
    from public.cafes c
    join public.profiles p on p.id = c.owner_id
    where c.id = campaigns.cafe_id
      and c.owner_id = (select auth.uid())
      and p.approval_status = 'approved'
  )
);
