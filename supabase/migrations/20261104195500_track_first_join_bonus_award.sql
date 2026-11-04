alter table public.campaign_memberships
  add column if not exists bonus_stamps_awarded integer not null default 0;

alter table public.campaign_memberships
  drop constraint if exists campaign_memberships_bonus_stamps_awarded_check;

alter table public.campaign_memberships
  add constraint campaign_memberships_bonus_stamps_awarded_check
  check (bonus_stamps_awarded >= 0);

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

  new.bonus_stamps_awarded := coalesce(v_bonus, 0);
  new.stamps := new.bonus_stamps_awarded;
  return new;
end;
$function$;