create table public.professional_registration_requests (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  request_type text not null check (request_type in ('agent', 'broker')),
  brokerage_id uuid references public.brokerages(id),
  brokerage_name text,
  contact_phone text not null check (char_length(btrim(contact_phone)) between 7 and 30),
  contact_address text not null check (char_length(btrim(contact_address)) between 8 and 500),
  status text not null default 'submitted' check (status in ('submitted', 'brokerage_approved', 'properap_approved', 'payment_pending', 'activated', 'denied', 'withdrawn')),
  brokerage_decided_by uuid references public.people(id),
  brokerage_decided_at timestamptz,
  properap_decided_by uuid references public.people(id),
  properap_decided_at timestamptz,
  decision_reason text check (decision_reason is null or char_length(decision_reason) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((request_type = 'agent' and brokerage_id is not null and brokerage_name is null) or (request_type = 'broker' and brokerage_id is null and brokerage_name is not null))
);
create unique index professional_registration_one_open_idx on public.professional_registration_requests(person_id)
  where status in ('submitted', 'brokerage_approved', 'properap_approved', 'payment_pending');
create index professional_registration_status_idx on public.professional_registration_requests(status, created_at);
alter table public.professional_registration_requests enable row level security;
create policy professional_registration_read_self on public.professional_registration_requests
  for select to authenticated
  using (person_id = app_private.current_person_id());
revoke all on public.professional_registration_requests from anon, authenticated;
grant select on public.professional_registration_requests to authenticated;
grant select, insert, update, delete on public.professional_registration_requests to service_role;
create trigger professional_registration_touch_updated_at before update on public.professional_registration_requests for each row execute function app_private.touch_updated_at();

create or replace function app_private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text;
  supplied_first_name text;
  supplied_last_name text;
  requested_role text;
  target_person_id uuid;
  target_brokerage_id uuid;
  brokerage_name_value text;
  phone_value text;
  address_value text;
begin
  supplied_name := left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'New User'), 120);
  supplied_first_name := left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'first_name'), ''), nullif(btrim(split_part(supplied_name, ' ', 1)), ''), 'New'), 80);
  supplied_last_name := left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'last_name'), ''), app_private.name_last_part(supplied_name)), 80);
  requested_role := coalesce(nullif(btrim(lower(new.raw_user_meta_data ->> 'requested_role')), ''), 'consumer');
  if requested_role not in ('consumer', 'agent', 'broker') then requested_role := 'consumer'; end if;
  insert into public.people (auth_user_id, first_name, last_name, display_name, primary_email, primary_phone, account_status)
  values (new.id, supplied_first_name, supplied_last_name, concat_ws(' ', supplied_first_name, supplied_last_name), nullif(lower(btrim(coalesce(new.email, ''))), ''), nullif(btrim(new.raw_user_meta_data ->> 'contact_phone'), ''), case when requested_role = 'consumer' then 'active' else 'inactive' end)
  returning id into target_person_id;

  if requested_role in ('agent', 'broker') then
    phone_value := nullif(btrim(new.raw_user_meta_data ->> 'contact_phone'), '');
    address_value := nullif(btrim(new.raw_user_meta_data ->> 'contact_address'), '');
    if phone_value is null or address_value is null then
      raise exception 'Professional registration requires a phone number and address';
    end if;
    if requested_role = 'agent' then
      if coalesce(new.raw_user_meta_data ->> 'brokerage_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
        raise exception 'Agent registration requires a brokerage';
      end if;
      target_brokerage_id := (new.raw_user_meta_data ->> 'brokerage_id')::uuid;
      if not exists (select 1 from public.brokerages where id = target_brokerage_id and status = 'active') then
        raise exception 'Selected brokerage is not accepting registrations';
      end if;
      insert into public.professional_registration_requests (person_id, request_type, brokerage_id, contact_phone, contact_address)
      values (target_person_id, 'agent', target_brokerage_id, phone_value, address_value);
      insert into public.agent_applications (person_id, brokerage_id, status, submitted_at)
      values (target_person_id, target_brokerage_id, 'submitted', now());
    else
      brokerage_name_value := nullif(btrim(new.raw_user_meta_data ->> 'brokerage_name'), '');
      if brokerage_name_value is null then raise exception 'Broker registration requires a brokerage name'; end if;
      insert into public.professional_registration_requests (person_id, request_type, brokerage_name, contact_phone, contact_address)
      values (target_person_id, 'broker', brokerage_name_value, phone_value, address_value);
    end if;
  end if;
  return new;
end;
$$;

create or replace function app_private.process_agent_application_decision_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  target_application public.agent_applications%rowtype;
  actor_effective_role text;
begin
  actor_person_id := app_private.current_person_id();
  select * into target_application from public.agent_applications where id = new.application_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'Application not found'; end if;
  if actor_person_id is null or not app_private.has_brokerage_permission(target_application.brokerage_id, 'agent.manage') then raise exception using errcode = '42501', message = 'Permission denied'; end if;
  select case when exists (select 1 from public.brokerage_memberships membership join public.membership_roles role on role.membership_id = membership.id where membership.person_id = actor_person_id and membership.brokerage_id = target_application.brokerage_id and membership.status = 'active' and role.role_key = 'broker' and role.ends_at is null) then 'broker' else 'broker_staff' end into actor_effective_role;
  if target_application.status <> 'submitted' then raise exception using errcode = '22023', message = 'Application is not awaiting a decision'; end if;
  if new.decision = 'deny' and nullif(btrim(coalesce(new.reason, '')), '') is null then raise exception using errcode = '22023', message = 'A reason is required when declining an application'; end if;
  if new.decision = 'approve' then
    update public.agent_applications set status = 'broker_approved', broker_decided_by = actor_person_id, broker_decided_at = now(), broker_reason = nullif(btrim(coalesce(new.reason, '')), '') where id = target_application.id;
    update public.professional_registration_requests set status = 'brokerage_approved', brokerage_decided_by = actor_person_id, brokerage_decided_at = now(), decision_reason = nullif(btrim(coalesce(new.reason, '')), '') where person_id = target_application.person_id and request_type = 'agent' and brokerage_id = target_application.brokerage_id and status = 'submitted';
  else
    update public.agent_applications set status = 'broker_denied', broker_decided_by = actor_person_id, broker_decided_at = now(), broker_reason = btrim(new.reason) where id = target_application.id;
    update public.professional_registration_requests set status = 'denied', brokerage_decided_by = actor_person_id, brokerage_decided_at = now(), decision_reason = btrim(new.reason) where person_id = target_application.person_id and request_type = 'agent' and brokerage_id = target_application.brokerage_id and status = 'submitted';
  end if;
  insert into public.audit_events (actor_person_id, effective_role_key, brokerage_id, action, target_type, target_id, source, correlation_id, reason, before_summary, after_summary)
  values (actor_person_id, actor_effective_role, target_application.brokerage_id, case when new.decision = 'approve' then 'agent_application.broker_approved' else 'agent_application.denied' end, 'agent_application', target_application.id, 'web', gen_random_uuid(), nullif(btrim(coalesce(new.reason, '')), ''), jsonb_build_object('status', target_application.status), jsonb_build_object('status', case when new.decision = 'approve' then 'broker_approved' else 'broker_denied' end));
  return null;
end;
$$;

revoke all on function app_private.handle_new_auth_user() from public, anon, authenticated;
revoke all on function app_private.process_agent_application_decision_command() from public, anon, authenticated;
