begin;
select plan(20);

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('54000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls.broker@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"RLS Broker"}',now(),now()),
('54000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls.agent@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"RLS Agent"}',now(),now()),
('54000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls.staff@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"RLS Staff"}',now(),now()),
('54000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls.otherbroker@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Other RLS Broker"}',now(),now());

insert into public.brokerages (id,slug,legal_name,display_name,status,country_id) values
('64000000-0000-4000-8000-000000000001','rls-realty','RLS Realty Limited','RLS Realty','active',(select id from public.countries where code='JM')),
('64000000-0000-4000-8000-000000000002','other-rls-realty','Other RLS Realty Limited','Other RLS Realty','active',(select id from public.countries where code='JM'));
insert into public.brokerage_memberships (id,brokerage_id,person_id,status,starts_at) values
('74000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000001'),'active',now()),
('74000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000002'),'active',now()),
('74000000-0000-4000-8000-000000000003','64000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000003'),'active',now()),
('74000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000002',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000004'),'active',now());
insert into public.membership_roles (membership_id,brokerage_id,role_key) values
('74000000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','broker'),
('74000000-0000-4000-8000-000000000002','64000000-0000-4000-8000-000000000001','agent'),
('74000000-0000-4000-8000-000000000003','64000000-0000-4000-8000-000000000001','broker_staff'),
('74000000-0000-4000-8000-000000000004','64000000-0000-4000-8000-000000000002','broker');

insert into public.property_addresses (id,country_id,administrative_area_id,address_line_1,normalized_address,created_by_brokerage_id,created_by_person_id) values
('83100000-0000-4000-8000-000000000001',(select id from public.countries where code='JM'),(select id from public.administrative_areas where code='JM-08'),'20 Private Road','20 private road saint james jamaica','64000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000002'));
insert into public.properties (id,created_by_brokerage_id,created_by_person_id,property_type,address_id,address_fingerprint) values
('84100000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000002'),'residential','83100000-0000-4000-8000-000000000001',repeat('b',64));
insert into public.listings (id,brokerage_id,property_id,created_by_person_id) values
('85100000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','84100000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000002'));
insert into public.listing_assignments (id,listing_id,brokerage_id,agent_membership_id,status,starts_at,assigned_by_person_id) values
('86100000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001','64000000-0000-4000-8000-000000000001','74000000-0000-4000-8000-000000000002','active',now(),(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000001'));
insert into public.listing_versions (id,listing_id,version_number,purpose,property_type,currency,price,title,description,created_by_person_id) values
('87100000-0000-4000-8000-000000000001','85100000-0000-4000-8000-000000000001',1,'sale','residential','JMD',50000000,'Private RLS test home','A private draft used to verify strict brokerage listing isolation.',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000002'));

set local role anon;
select results_eq($$select count(*)::bigint from public.administrative_areas where country_id=(select id from public.countries where code='JM')$$,$$values (14::bigint)$$,'visitors can read Jamaican public geography references');
select throws_like($$select * from public.listings$$,'%permission denied%','visitors cannot query raw listings');
select lives_ok($$select * from public.localities$$,'visitors can query the public locality catalogue');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select results_eq($$select count(*)::bigint from public.listings$$,$$values (1::bigint)$$,'assigned agent can read their listing');
select results_eq($$select count(*)::bigint from public.listing_versions$$,$$values (1::bigint)$$,'assigned agent can read their draft version');
select results_eq($$select count(*)::bigint from public.listing_assignments$$,$$values (1::bigint)$$,'assigned agent can read assignment history for their listing');
select results_eq($$select count(*)::bigint from public.properties$$,$$values (1::bigint)$$,'assigned agent can read the linked property');
select results_eq($$select count(*)::bigint from public.property_addresses$$,$$values (1::bigint)$$,'assigned agent can read the exact linked address');
select throws_like($$insert into public.listings (brokerage_id,property_id,created_by_person_id) values ('64000000-0000-4000-8000-000000000001','84100000-0000-4000-8000-000000000001',(select id from public.people limit 1))$$,'%permission denied%','authenticated users cannot bypass listing command services');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select is_empty($$select * from public.listings$$,'ordinary staff cannot browse private drafts without a capability');
select is_empty($$select * from public.properties$$,'ordinary staff cannot retrieve private property records');
select is_empty($$select * from public.property_addresses$$,'ordinary staff cannot retrieve exact addresses');
reset role;

insert into public.membership_permissions (membership_id,permission_key,effect,granted_by_person_id) values
('74000000-0000-4000-8000-000000000003','listing.review','allow',(select id from public.people where auth_user_id='54000000-0000-4000-8000-000000000001'));
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select results_eq($$select count(*)::bigint from public.listings$$,$$values (1::bigint)$$,'staff with listing review capability can read brokerage listings');
select results_eq($$select count(*)::bigint from public.listing_versions$$,$$values (1::bigint)$$,'authorized reviewer can read submitted listing content');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select results_eq($$select count(*)::bigint from public.listings$$,$$values (1::bigint)$$,'principal broker can read the brokerage portfolio');
select results_eq($$select count(*)::bigint from public.property_addresses$$,$$values (1::bigint)$$,'principal broker can read brokerage property addresses');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select is_empty($$select * from public.listings$$,'another brokerage cannot read the listing');
select is_empty($$select * from public.property_addresses$$,'another brokerage cannot read the exact address');
reset role;

update public.brokerage_memberships set status='departed',ends_at=now() where id='74000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is_empty($$select * from public.listings$$,'departed agent immediately loses private listing access');
select is_empty($$select * from public.listing_versions$$,'departed agent immediately loses version access');

select * from finish();
rollback;
