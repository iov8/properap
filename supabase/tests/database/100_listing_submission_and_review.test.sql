begin;
select plan(30);

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('58000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','submit.agent@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Submit Agent"}',now(),now()),
('58000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','submit.other@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Other Agent"}',now(),now()),
('58000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','submit.staff@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Review Staff"}',now(),now()),
('58000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','submit.broker@example.test','',now(),'{"provider":"email","providers":["email"]}','{"display_name":"Review Broker"}',now(),now());
insert into public.brokerages (id,slug,legal_name,display_name,status,country_id) values
('68000000-0000-4000-8000-000000000001','submission-realty','Submission Realty Limited','Submission Realty','active',(select id from public.countries where code='JM'));
insert into public.brokerage_memberships (id,brokerage_id,person_id,status,starts_at) values
('78000000-0000-4000-8000-000000000001','68000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='58000000-0000-4000-8000-000000000001'),'active',now()),
('78000000-0000-4000-8000-000000000002','68000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='58000000-0000-4000-8000-000000000002'),'active',now()),
('78000000-0000-4000-8000-000000000003','68000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='58000000-0000-4000-8000-000000000003'),'active',now()),
('78000000-0000-4000-8000-000000000004','68000000-0000-4000-8000-000000000001',(select id from public.people where auth_user_id='58000000-0000-4000-8000-000000000004'),'active',now());
insert into public.membership_roles (membership_id,brokerage_id,role_key) values
('78000000-0000-4000-8000-000000000001','68000000-0000-4000-8000-000000000001','agent'),
('78000000-0000-4000-8000-000000000002','68000000-0000-4000-8000-000000000001','agent'),
('78000000-0000-4000-8000-000000000003','68000000-0000-4000-8000-000000000001','broker_staff'),
('78000000-0000-4000-8000-000000000004','68000000-0000-4000-8000-000000000001','broker'),
('78000000-0000-4000-8000-000000000004','68000000-0000-4000-8000-000000000001','agent');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
insert into public.create_listing_draft_commands (listing_id,administrative_area_id,address_line_1,purpose,property_type,price,title,description,bedrooms,bathrooms,visibility,public_location_precision)
values ('89000000-0000-4000-8000-000000000101',(select id from public.administrative_areas where code='JM-02'),'101 Review Road','sale','residential',41000000,'Submission workflow home','A complete private draft used to verify atomic brokerage submission and review.',3,2,'public','area');
reset role;
select set_config('test.submission_version_id',(select id::text from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),false);

set local role anon;
select throws_like($$insert into public.submit_listing_version_commands (request_id,listing_id,listing_version_id,expected_lock_version) values (gen_random_uuid(),'89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),1)$$,'%permission denied%','visitors cannot submit listing versions');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_like($$insert into public.submit_listing_version_commands (request_id,listing_id,listing_version_id,expected_lock_version) values (gen_random_uuid(),'89000000-0000-4000-8000-000000000101',current_setting('test.submission_version_id')::uuid,1)$$,'%Only the active listing representative%','another brokerage agent cannot submit the assigned agent draft');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_like($$insert into public.submit_listing_version_commands (request_id,listing_id,listing_version_id,expected_lock_version) values (gen_random_uuid(),'89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),1)$$,'%validated property image%','submission requires at least one validated property image');
insert into public.authorize_listing_media_upload_commands (media_id,listing_id,original_filename,declared_mime_type,declared_byte_size,object_path) values
('90000000-0000-4000-8000-000000000101','89000000-0000-4000-8000-000000000101','review-home.jpg','image/jpeg',2048,'68000000-0000-4000-8000-000000000001/89000000-0000-4000-8000-000000000101/90000000-0000-4000-8000-000000000101/original.jpg');
reset role;
update public.listing_media set status='ready',detected_mime_type='image/jpeg',actual_byte_size=2048,width=1200,height=800,validated_at=now(),updated_at=now() where id='90000000-0000-4000-8000-000000000101';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$insert into public.submit_listing_version_commands (request_id,listing_id,listing_version_id,expected_lock_version) values ('91000000-0000-4000-8000-000000000101','89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),1)$$,'the assigned agent can atomically submit a complete draft');
reset role;
select results_eq($$select lifecycle_state,lock_version from public.listings where id='89000000-0000-4000-8000-000000000101'$$,$$values ('pending_initial_approval'::text,2)$$,'submission advances the listing and optimistic lock together');
select results_eq($$select revision_state,submitted_by_person_id is not null,submitted_at is not null,frozen_at is not null,content_hash ~ '^[0-9a-f]{64}$' from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'$$,$$values ('submitted'::text,true,true,true,true)$$,'the exact submitted version is attributed, frozen, and hashed');
select results_eq($$select count(*)::bigint from public.listing_state_events where listing_id='89000000-0000-4000-8000-000000000101' and from_state='draft' and to_state='pending_initial_approval'$$,$$values (1::bigint)$$,'submission appends one lifecycle event');
select results_eq($$select count(*)::bigint from public.audit_events where target_id='89000000-0000-4000-8000-000000000101' and action='listing.submitted'$$,$$values (1::bigint)$$,'submission appends a privacy-safe audit event');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_like($$update public.listing_versions set price=1 where listing_id='89000000-0000-4000-8000-000000000101'$$,'%permission denied%','the agent cannot directly mutate the submitted snapshot');
select throws_like($$select * from public.submit_listing_version_commands$$,'%permission denied%','submission commands are write only');
select throws_like($$insert into public.listing_reviews (listing_version_id,reviewer_person_id,reviewer_membership_id,decision) values ((select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),(select id from public.people where auth_user_id='58000000-0000-4000-8000-000000000001'),'78000000-0000-4000-8000-000000000001','approved')$$,'%permission denied%','agents cannot bypass the review command with a direct decision insert');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_like($$insert into public.decide_listing_review_commands (request_id,review_id,listing_id,listing_version_id,decision,comment) values (gen_random_uuid(),gen_random_uuid(),'89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),'approved',null)$$,'%review authority%','broker staff without delegated review permission cannot decide a submission');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
insert into public.membership_permission_commands (membership_id,permission_key,operation,reason) values ('78000000-0000-4000-8000-000000000003','listing.review','grant','Authorized listing reviewer');
reset role;
select results_eq($$select effect from public.membership_permissions where membership_id='78000000-0000-4000-8000-000000000003' and permission_key='listing.review' and ends_at is null$$,$$values ('allow'::text)$$,'the broker can delegate listing review to staff');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_like($$insert into public.decide_listing_review_commands (request_id,review_id,listing_id,listing_version_id,decision,comment) values (gen_random_uuid(),gen_random_uuid(),'89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),'changes_requested',null)$$,'%clear reviewer comment%','correction requests require a reviewer explanation');
select lives_ok($$insert into public.decide_listing_review_commands (request_id,review_id,listing_id,listing_version_id,decision,comment) values ('91000000-0000-4000-8000-000000000102','92000000-0000-4000-8000-000000000101','89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101'),'changes_requested','Correct the public description before approval.')$$,'authorized broker staff can request specific corrections');
reset role;
select results_eq($$select decision,comment,is_self_approval from public.listing_reviews where id='92000000-0000-4000-8000-000000000101'$$,$$values ('changes_requested'::text,'Correct the public description before approval.'::text,false)$$,'the decision retains its comment and self-approval attribution');
select results_eq($$select revision_state from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101' order by version_number$$,$$values ('changes_requested'::text),('working_draft'::text)$$,'the returned snapshot remains immutable beside a new working version');
select results_eq($$select based_on_version_id is not null,created_by_person_id=(select id from public.people where auth_user_id='58000000-0000-4000-8000-000000000001') from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101' and revision_state='working_draft'$$,$$values (true,true)$$,'the correction draft is based on the returned version and assigned to the submitter');
select results_eq($$select lifecycle_state,lock_version from public.listings where id='89000000-0000-4000-8000-000000000101'$$,$$values ('draft'::text,3)$$,'requesting changes returns the listing to draft atomically');
select results_eq($$select count(*)::bigint from public.listing_version_media where listing_version_id=(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101' and revision_state='working_draft')$$,$$values (1::bigint)$$,'the correction draft receives the validated media set');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$insert into public.submit_listing_version_commands (request_id,listing_id,listing_version_id,expected_lock_version) values ('91000000-0000-4000-8000-000000000103','89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101' and revision_state='working_draft'),3)$$,'the agent can resubmit the returned correction version');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select lives_ok($$insert into public.decide_listing_review_commands (request_id,review_id,listing_id,listing_version_id,decision,comment) values ('91000000-0000-4000-8000-000000000104','92000000-0000-4000-8000-000000000102','89000000-0000-4000-8000-000000000101',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000101' and revision_state='submitted'),'approved','Correction confirmed.')$$,'the broker can approve the resubmitted version');
reset role;
select results_eq($$select lifecycle_state,current_approved_version_id is not null,lock_version from public.listings where id='89000000-0000-4000-8000-000000000101'$$,$$values ('approved_inactive'::text,true,5)$$,'approval establishes canonical content but keeps public activation fail closed');
select results_eq($$select revision_state,approved_at is not null from public.listing_versions where id=(select current_approved_version_id from public.listings where id='89000000-0000-4000-8000-000000000101')$$,$$values ('approved'::text,true)$$,'the approved pointer references the exact decided version');
select results_eq($$select is_self_approval from public.listing_reviews where id='92000000-0000-4000-8000-000000000102'$$,$$values (false)$$,'a broker decision on another agent submission is not self-approval');
select results_eq($$select count(*)::bigint from public.audit_events where target_id='89000000-0000-4000-8000-000000000101' and action='listing.reviewed'$$,$$values (2::bigint)$$,'every brokerage decision receives its own append-only audit event');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
insert into public.create_listing_draft_commands (listing_id,administrative_area_id,address_line_1,purpose,property_type,price,title,description,bedrooms,bathrooms,visibility,public_location_precision)
values ('89000000-0000-4000-8000-000000000102',(select id from public.administrative_areas where code='JM-08'),'102 Broker Lane','sale','residential',52000000,'Broker represented home','A broker who also acts as the assigned agent may submit and approve this listing.',4,3,'public','area');
insert into public.authorize_listing_media_upload_commands (media_id,listing_id,original_filename,declared_mime_type,declared_byte_size,object_path) values
('90000000-0000-4000-8000-000000000102','89000000-0000-4000-8000-000000000102','broker-home.jpg','image/jpeg',3000,'68000000-0000-4000-8000-000000000001/89000000-0000-4000-8000-000000000102/90000000-0000-4000-8000-000000000102/original.jpg');
reset role;
update public.listing_media set status='ready',detected_mime_type='image/jpeg',actual_byte_size=3000,width=1400,height=900,validated_at=now(),updated_at=now() where id='90000000-0000-4000-8000-000000000102';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select lives_ok($$insert into public.submit_listing_version_commands (request_id,listing_id,listing_version_id,expected_lock_version) values (gen_random_uuid(),'89000000-0000-4000-8000-000000000102',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000102'),1)$$,'a broker acting as the assigned agent can submit once with one account');
select lives_ok($$insert into public.decide_listing_review_commands (request_id,review_id,listing_id,listing_version_id,decision,comment) values (gen_random_uuid(),'92000000-0000-4000-8000-000000000103','89000000-0000-4000-8000-000000000102',(select id from public.listing_versions where listing_id='89000000-0000-4000-8000-000000000102'),'approved','Self-reviewed under delegated broker authority.')$$,'an authorized broker-agent can approve their own submission');
reset role;
select results_eq($$select is_self_approval from public.listing_reviews where id='92000000-0000-4000-8000-000000000103'$$,$$values (true)$$,'authorized self-approval is explicitly recorded');
select results_eq($$select count(*)::bigint from public.listing_state_events where listing_id='89000000-0000-4000-8000-000000000102' and to_state='approved_inactive'$$,$$values (1::bigint)$$,'self-approval still follows the same fail-closed lifecycle transition');

select * from finish();
rollback;
