begin;

select plan(6);

select has_schema(
  'app_private',
  'the internal application schema exists'
);

select ok(
  not has_schema_privilege('anon', 'app_private', 'usage'),
  'anonymous Data API role cannot use the internal schema'
);

select ok(
  not has_schema_privilege('authenticated', 'app_private', 'usage'),
  'authenticated Data API role cannot use the internal schema'
);

select ok(
  not has_schema_privilege('public', 'app_private', 'usage'),
  'PUBLIC cannot use the internal schema'
);

select is(
  (
    select count(*)::bigint
    from pg_class as relation
    join pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname in ('public', 'graphql_public')
      and relation.relkind in ('r', 'p')
      and not relation.relrowsecurity
  ),
  0::bigint,
  'every table in an exposed schema has row level security enabled'
);

select is(
  (
    select count(*)::bigint
    from pg_proc as function
    join pg_namespace as namespace
      on namespace.oid = function.pronamespace
    where namespace.nspname in ('public', 'app_private')
      and function.prosecdef
      and has_function_privilege('public', function.oid, 'execute')
  ),
  0::bigint,
  'no application security-definer function is executable by PUBLIC'
);

select * from finish();

rollback;
