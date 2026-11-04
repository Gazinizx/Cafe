alter table public.campaigns
  add column if not exists first_join_bonus_stamps integer not null default 0;

alter table public.campaigns
  drop constraint if exists campaigns_first_join_bonus_stamps_check;

alter table public.campaigns
  add constraint campaigns_first_join_bonus_stamps_check
  check (
    first_join_bonus_stamps >= 0
    and first_join_bonus_stamps < stamps_required
  );

create or replace function private.apply_campaign_first_join_bonus()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_bonus integer;
begin
  select c.first_join_bonus_stamps
    into v_bonus
  from public.campaigns c
  where c.id = new.campaign_id
    and c.is_active = true;

  if not found then
    raise exception 'Kampanya bulunamadı veya aktif değil';
  end if;

  -- Always derive the opening balance from campaign settings.
  -- Never trust a client-supplied membership.stamps value.
  new.stamps := coalesce(v_bonus, 0);
  return new;
end;
$function$;

drop trigger if exists campaign_membership_first_join_bonus on public.campaign_memberships;
create trigger campaign_membership_first_join_bonus
before insert on public.campaign_memberships
for each row
execute function private.apply_campaign_first_join_bonus();
