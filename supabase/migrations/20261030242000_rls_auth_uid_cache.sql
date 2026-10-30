-- Cache auth.uid() once per statement in RLS expressions instead of per row.
do $optimize$
declare
  p record;
  v_sql text;
  v_roles text;
  v_qual text;
  v_check text;
begin
  for p in
    select schemaname, tablename, policyname, permissive, cmd, roles, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') like '%auth.uid()%'
        or coalesce(with_check, '') like '%auth.uid()%')
  loop
    v_qual := p.qual;
    v_check := p.with_check;
    if v_qual is not null then
      v_qual := replace(v_qual, 'SELECT auth.uid()', '__AUTH_UID_SELECT__');
      v_qual := replace(v_qual, 'select auth.uid()', '__AUTH_UID_SELECT__');
      v_qual := replace(v_qual, 'auth.uid()', '(select auth.uid())');
      v_qual := replace(v_qual, '__AUTH_UID_SELECT__', 'auth.uid()');
    end if;
    if v_check is not null then
      v_check := replace(v_check, 'SELECT auth.uid()', '__AUTH_UID_SELECT__');
      v_check := replace(v_check, 'select auth.uid()', '__AUTH_UID_SELECT__');
      v_check := replace(v_check, 'auth.uid()', '(select auth.uid())');
      v_check := replace(v_check, '__AUTH_UID_SELECT__', 'auth.uid()');
    end if;
    if v_qual is not distinct from p.qual and v_check is not distinct from p.with_check then
      continue;
    end if;
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    v_roles := array_to_string(p.roles, ', ');
    v_sql := format('create policy %I on %I.%I as %s for %s to %s',
      p.policyname, p.schemaname, p.tablename, p.permissive, p.cmd, v_roles);
    if v_qual is not null then v_sql := v_sql || ' using (' || v_qual || ')'; end if;
    if v_check is not null then v_sql := v_sql || ' with check (' || v_check || ')'; end if;
    execute v_sql;
  end loop;
end;
$optimize$;
