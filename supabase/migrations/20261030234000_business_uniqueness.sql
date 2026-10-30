-- Enforce one active main branch and one active employer per employee account in the initial app experience.
create unique index if not exists cafes_one_main_branch_per_business_idx
on public.cafes(business_id) where is_main_branch = true;

create unique index if not exists business_employees_one_active_business_idx
on public.business_employees(employee_id) where is_active = true;
