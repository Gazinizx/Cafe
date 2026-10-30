-- New businesses must receive exactly one default main branch from the auth signup trigger.
with businesses_without_main as (
  select business_id
  from public.cafes
  group by business_id
  having count(*) filter (where is_main_branch) = 0
), first_branch as (
  select distinct on (c.business_id) c.id, c.business_id
  from public.cafes c
  join businesses_without_main b on b.business_id = c.business_id
  order by c.business_id, c.created_at, c.id
)
update public.cafes c set is_main_branch = true
from first_branch f where f.id = c.id;

alter table public.cafes alter column is_main_branch set default true;
