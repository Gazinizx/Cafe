alter table public.cafes
  add column if not exists phone text,
  add column if not exists website_url text,
  add column if not exists menu_url text,
  add column if not exists opening_hours text,
  add column if not exists cover_image_url text;

create or replace function private.notify_reward_issued()
returns trigger language plpgsql security definer set search_path = ''
as $function$
begin
  if new.status = 'issued' then
    insert into public.user_notifications(user_id, title, body, notification_type, metadata)
    values (
      new.customer_id, 'Ödülün hazır!',
      coalesce(new.reward_snapshot ->> 'title', new.reward_snapshot ->> 'reward_title', 'Kazandığın ödül') || ' işletmede seni bekliyor.',
      'reward', jsonb_build_object('campaign_id', new.campaign_id, 'reward_claim_id', new.id)
    );
  end if;
  return new;
end;
$function$;
revoke all on function private.notify_reward_issued() from public, anon, authenticated;
