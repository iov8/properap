-- Supabase projects with "RLS on by default" may install this event-trigger
-- helper in the exposed public schema with permissive default EXECUTE grants.
-- The event trigger does not require Data API roles to call the function.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated, service_role';
  end if;
end;
$$;
