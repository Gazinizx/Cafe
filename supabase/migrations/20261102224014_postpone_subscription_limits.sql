-- Package tiers are intentionally postponed. Keep ownership integrity but do not
-- block the free launch on branch or employee subscription limits.
create or replace function private.enforce_business_limits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or public.is_cafe_admin() then
    return new;
  end if;
  if new.business_id <> auth.uid() then
    raise exception 'Business ownership mismatch';
  end if;
  if tg_op = 'UPDATE' and new.business_id <> old.business_id then
    raise exception 'Business ownership cannot be changed';
  end if;
  return new;
end;
$function$;
revoke all on function private.enforce_business_limits() from public, anon, authenticated;
