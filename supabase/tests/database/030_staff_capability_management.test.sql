begin;

select plan(16);

select has_table(
  'public',
  'membership_permission_commands',
  'staff capability command boundary exists'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) values
  ('51000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'capability.broker@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Capability Broker"}', now(), now()),
  ('51000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'capability.staff@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Capability Staff"}', now(), now()),
  ('51000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'capability.agent@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Capability Agent"}', now(), now()),
  ('51000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'capability.otherbroker@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Other Broker"}', now(), now()),
  ('51000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'capability.otherstaff@example.test', '', now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Other Staff"}', now(), now());

insert into public.brokerages (id, slug, legal_name, display_name, status, country_id)
values
  ('61000000-0000-4000-8000-000000000001', 'capability-realty', 'Capability Realty Limited', 'Capability Realty', 'active', (select id from public.countries where code = 'JM')),
  ('61000000-0000-4000-8000-000000000002', 'other-capability-realty', 'Other Capability Realty Limited', 'Other Capability Realty', 'active', (select id from public.countries where code = 'JM'));

insert into public.brokerage_memberships (id, brokerage_id, person_id, status, starts_at)
values
  ('71000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', (select id from public.people where auth_user_id = '51000000-0000-4000-8000-000000000001'), 'active', now()),
  ('71000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000001', (select id from public.people where auth_user_id = '51000000-0000-4000-8000-000000000002'), 'active', now()),
  ('71000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000001', (select id from public.people where auth_user_id = '51000000-0000-4000-8000-000000000003'), 'active', now()),
  ('71000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000002', (select id from public.people where auth_user_id = '51000000-0000-4000-8000-000000000004'), 'active', now()),
  ('71000000-0000-4000-8000-000000000005', '61000000-0000-4000-8000-000000000002', (select id from public.people where auth_user_id = '51000000-0000-4000-8000-000000000005'), 'active', now());

insert into public.membership_roles (membership_id, brokerage_id, role_key)
values
  ('71000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', 'broker'),
  ('71000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000001', 'broker_staff'),
  ('71000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000001', 'agent'),
  ('71000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000002', 'broker'),
  ('71000000-0000-4000-8000-000000000005', '61000000-0000-4000-8000-000000000002', 'broker_staff');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select lives_ok(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation, reason)
     values ('71000000-0000-4000-8000-000000000002', 'listing.review', 'grant', 'Office approver') $$,
  'the principal broker can grant a capability to active staff'
);

reset role;

select results_eq(
  $$ select effect from public.membership_permissions
     where membership_id = '71000000-0000-4000-8000-000000000002'
       and permission_key = 'listing.review' and ends_at is null $$,
  $$ values ('allow'::text) $$,
  'the grant creates one active explicit allow'
);

select results_eq(
  $$ select count(*)::bigint from public.audit_events
     where action = 'membership_permission.granted'
       and target_id = '71000000-0000-4000-8000-000000000002' $$,
  $$ values (1::bigint) $$,
  'the capability grant is audited'
);

select is_empty(
  $$ select * from public.membership_permission_commands $$,
  'command rows are never persisted'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select lives_ok(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation)
     values ('71000000-0000-4000-8000-000000000002', 'listing.review', 'grant') $$,
  'repeating a grant is safely idempotent'
);

reset role;

select results_eq(
  $$ select count(*)::bigint from public.membership_permissions
     where membership_id = '71000000-0000-4000-8000-000000000002'
       and permission_key = 'listing.review' and ends_at is null $$,
  $$ values (1::bigint) $$,
  'an idempotent grant does not duplicate the active permission'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

select throws_like(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation)
     values ('71000000-0000-4000-8000-000000000002', 'report.view', 'grant') $$,
  '%Only the principal broker%',
  'broker staff cannot grant capabilities'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select throws_like(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation)
     values ('71000000-0000-4000-8000-000000000005', 'report.view', 'grant') $$,
  '%Only the principal broker%',
  'a broker cannot alter another brokerage staff membership'
);

select throws_like(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation)
     values ('71000000-0000-4000-8000-000000000003', 'report.view', 'grant') $$,
  '%only to active broker staff%',
  'an agent-only membership cannot receive staff capabilities'
);

select throws_like(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation)
     values ('71000000-0000-4000-8000-000000000002', 'listing.create', 'grant') $$,
  '%not delegable%',
  'agent-only permissions cannot be delegated as staff capabilities'
);

select lives_ok(
  $$ insert into public.membership_permission_commands (membership_id, permission_key, operation, reason)
     values ('71000000-0000-4000-8000-000000000002', 'listing.review', 'revoke', 'Changed duties') $$,
  'the principal broker can revoke a staff capability'
);

reset role;

select is_empty(
  $$ select * from public.membership_permissions
     where membership_id = '71000000-0000-4000-8000-000000000002'
       and permission_key = 'listing.review' and ends_at is null $$,
  'revocation removes the active capability immediately'
);

select results_eq(
  $$ select count(*)::bigint from public.membership_permissions
     where membership_id = '71000000-0000-4000-8000-000000000002'
       and permission_key = 'listing.review' and ends_at is not null $$,
  $$ values (1::bigint) $$,
  'revocation preserves the historical grant'
);

select results_eq(
  $$ select count(*)::bigint from public.audit_events
     where action = 'membership_permission.revoked'
       and target_id = '71000000-0000-4000-8000-000000000002' $$,
  $$ values (1::bigint) $$,
  'the capability revocation is audited'
);

select is_empty(
  $$ select * from public.membership_permission_commands $$,
  'revoke command rows are also never persisted'
);

select * from finish();
rollback;
