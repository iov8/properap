begin;

-- A person becomes eligible to receive a brokerage listing only after ProperAP
-- has activated their independent-agent profile. This deliberately does not
-- treat a brokerage agent as independent simply because they are an agent.
create table public.independent_agent_profiles (
  person_id uuid primary key references public.people(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'inactive', 'closed')),
  activated_at timestamptz,
  deactivated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'active') = (activated_at is not null)),
  check (status <> 'closed' or deactivated_at is not null)
);
create index independent_agent_profiles_active_idx
  on public.independent_agent_profiles (person_id) where status = 'active';
alter table public.independent_agent_profiles enable row level security;
create policy independent_agent_profiles_self_read
  on public.independent_agent_profiles for select to authenticated
  using (person_id = app_private.current_person_id());
grant select on public.independent_agent_profiles to authenticated;

-- The transferable ownership field is intentionally separate from the
-- originating brokerage reference. During the existing brokerage workflow
-- brokerage_id remains authoritative. Once a transfer is accepted, the record
-- is held as a private independent-agent draft until the independent workflow
-- publishes it in a subsequent release.
alter table public.listings
  alter column brokerage_id drop not null,
  add column if not exists independent_owner_person_id uuid references public.people(id);
create index if not exists listings_independent_owner_idx
  on public.listings (independent_owner_person_id)
  where independent_owner_person_id is not null;

alter table public.listings
  drop constraint if exists listings_lifecycle_state_check;
alter table public.listings
  add constraint listings_lifecycle_state_check check (
    lifecycle_state in (
      'draft', 'pending_initial_approval', 'approved_inactive', 'active',
      'under_offer', 'withdrawn', 'sold', 'rented', 'expired', 'unassigned',
      'archived', 'transfer_pending'
    )
  );
alter table public.listings
  add constraint listings_owner_authority_check check (
    (brokerage_id is not null and independent_owner_person_id is null)
    or (brokerage_id is null and independent_owner_person_id is not null)
  );

-- Preserve the brokerage that supplied an assignment as historical context,
-- while allowing the listing itself to leave that brokerage after acceptance.
alter table public.listing_assignments
  add column if not exists historical_brokerage_id uuid references public.brokerages(id);
update public.listing_assignments
set historical_brokerage_id = brokerage_id
where historical_brokerage_id is null;
alter table public.listing_assignments
  alter column brokerage_id drop not null,
  drop constraint if exists listing_assignments_listing_id_brokerage_id_fkey,
  drop constraint if exists listing_assignments_agent_membership_id_brokerage_id_fkey;
alter table public.listing_assignments
  add constraint listing_assignments_listing_id_fkey foreign key (listing_id) references public.listings(id),
  add constraint listing_assignments_agent_membership_id_fkey foreign key (agent_membership_id) references public.brokerage_memberships(id);

alter table public.listing_state_events
  drop constraint if exists listing_state_events_from_state_check,
  drop constraint if exists listing_state_events_to_state_check;
alter table public.listing_state_events
  add constraint listing_state_events_from_state_check check (
    from_state is null or from_state in (
      'draft', 'pending_initial_approval', 'approved_inactive', 'active',
      'under_offer', 'withdrawn', 'sold', 'rented', 'expired', 'unassigned',
      'archived', 'transfer_pending'
    )
  ),
  add constraint listing_state_events_to_state_check check (
    to_state in (
      'draft', 'pending_initial_approval', 'approved_inactive', 'active',
      'under_offer', 'withdrawn', 'sold', 'rented', 'expired', 'unassigned',
      'archived', 'transfer_pending'
    )
  );

create table public.listing_transfer_out_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  source_brokerage_id uuid not null references public.brokerages(id),
  recipient_person_id uuid not null references public.people(id),
  initiated_by_person_id uuid not null references public.people(id),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  responded_at timestamptz,
  responded_by_person_id uuid references public.people(id),
  response_reason text check (response_reason is null or char_length(response_reason) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'pending' and responded_at is null and responded_by_person_id is null)
    or (status in ('accepted', 'declined') and responded_at is not null and responded_by_person_id = recipient_person_id)
    or (status in ('cancelled', 'expired') and responded_at is not null)
  )
);
create unique index listing_transfer_out_one_pending_idx
  on public.listing_transfer_out_requests (listing_id) where status = 'pending';
create index listing_transfer_out_recipient_idx
  on public.listing_transfer_out_requests (recipient_person_id, status, created_at desc);
alter table public.listing_transfer_out_requests enable row level security;
create policy listing_transfer_out_recipient_read
  on public.listing_transfer_out_requests for select to authenticated
  using (recipient_person_id = app_private.current_person_id());
grant select on public.listing_transfer_out_requests to authenticated;

alter table public.notifications drop constraint if exists notifications_event_type_check;
alter table public.notifications add constraint notifications_event_type_check check (event_type in (
  'listing.draft_created', 'listing.submitted', 'listing.approved', 'listing.changes_requested', 'listing.rejected',
  'listing.saved_listing_updated', 'inquiry.received', 'share.received', 'share.removed', 'share.revoked',
  'agent.application_submitted', 'membership.suspended', 'membership.reactivated', 'membership.removed', 'message.received',
  'listing.transfer_out_requested', 'listing.transfer_out_accepted', 'listing.transfer_out_declined'
));
alter table public.notifications drop constraint if exists notifications_target_type_check;
alter table public.notifications add constraint notifications_target_type_check check (
  target_type in ('listing', 'inquiry', 'share', 'agent_application', 'brokerage_membership', 'message', 'listing_transfer')
);

create table public.initiate_listing_transfer_out_commands (
  request_id uuid primary key,
  listing_id uuid not null references public.listings(id),
  recipient_person_id uuid not null references public.people(id),
  created_at timestamptz not null default now()
);
alter table public.initiate_listing_transfer_out_commands enable row level security;
create policy initiate_listing_transfer_out_authenticated_insert
  on public.initiate_listing_transfer_out_commands for insert to authenticated
  with check ((select auth.uid()) is not null);

create function app_private.process_initiate_listing_transfer_out_command()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor_person_id uuid;
  target_listing public.listings%rowtype;
  recipient public.people%rowtype;
  transfer_id uuid;
  event_id uuid;
  now_at timestamptz := clock_timestamp();
begin
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select * into target_listing from public.listings where id = new.listing_id for update;
  if not found or target_listing.brokerage_id is null then
    raise exception using errcode = 'P0002', message = 'Brokerage listing not found';
  end if;
  if not exists (
    select 1 from public.brokerage_memberships membership
    join public.membership_roles role on role.membership_id = membership.id
    where membership.person_id = actor_person_id
      and membership.brokerage_id = target_listing.brokerage_id
      and membership.status = 'active'
      and role.role_key = 'broker'
      and role.starts_at <= now_at and (role.ends_at is null or role.ends_at > now_at)
  ) then
    raise exception using errcode = '42501', message = 'Only the broker can transfer a brokerage listing out';
  end if;
  if target_listing.lifecycle_state in ('pending_initial_approval', 'transfer_pending', 'archived') then
    raise exception using errcode = '55000', message = 'This listing cannot be transferred in its current state';
  end if;
  if target_listing.current_approved_version_id is null then
    raise exception using errcode = '55000', message = 'Only an approved listing can be transferred out';
  end if;
  select * into recipient from public.people where id = new.recipient_person_id;
  if not found or recipient.account_status <> 'active' then
    raise exception using errcode = '22023', message = 'The receiving agent is not active';
  end if;
  if not exists (
    select 1 from public.independent_agent_profiles profile
    where profile.person_id = recipient.id and profile.status = 'active'
  ) or exists (
    select 1 from public.brokerage_memberships membership
    where membership.person_id = recipient.id and membership.status in ('active', 'suspended')
  ) then
    raise exception using errcode = '22023', message = 'Choose an active independent agent who is not currently with a brokerage';
  end if;

  insert into public.listing_transfer_out_requests (
    listing_id, source_brokerage_id, recipient_person_id, initiated_by_person_id
  ) values (
    target_listing.id, target_listing.brokerage_id, recipient.id, actor_person_id
  ) returning id into transfer_id;

  update public.listings
  set lifecycle_state = 'transfer_pending', published_at = null, unpublished_at = now_at,
      lock_version = lock_version + 1, updated_at = now_at
  where id = target_listing.id;
  insert into public.listing_state_events (
    listing_id, from_state, to_state, source_version_id, actor_person_id, reason, occurred_at
  ) values (
    target_listing.id, target_listing.lifecycle_state, 'transfer_pending', target_listing.current_approved_version_id,
    actor_person_id, 'Brokerage transfer-out awaiting independent-agent acceptance', now_at
  );
  insert into public.audit_events (
    actor_person_id, effective_role_key, brokerage_id, action, target_type, target_id, source,
    correlation_id, before_summary, after_summary, occurred_at
  ) values (
    actor_person_id, 'broker', target_listing.brokerage_id, 'listing.transfer_out_requested', 'listing_transfer', transfer_id,
    'web', new.request_id, jsonb_build_object('listing_id', target_listing.id, 'lifecycle_state', target_listing.lifecycle_state),
    jsonb_build_object('listing_id', target_listing.id, 'recipient_person_id', recipient.id, 'status', 'pending'), now_at
  ) returning event_id into event_id;
  insert into public.notifications (source_event_id, person_id, brokerage_id, event_type, title, body_safe, target_type, target_id, created_at)
  values (event_id, recipient.id, target_listing.brokerage_id, 'listing.transfer_out_requested',
    'A brokerage wants to transfer a listing to you', 'Accepting will make the listing your private independent-agent draft. Declining keeps it with the brokerage and unpublished.', 'listing_transfer', transfer_id, now_at);
  return null;
end;
$$;
create trigger process_initiate_listing_transfer_out_command before insert on public.initiate_listing_transfer_out_commands
  for each row execute function app_private.process_initiate_listing_transfer_out_command();
revoke all on function app_private.process_initiate_listing_transfer_out_command() from public, anon, authenticated;
revoke all on public.initiate_listing_transfer_out_commands from anon, authenticated;
grant insert on public.initiate_listing_transfer_out_commands to authenticated;

create table public.respond_listing_transfer_out_commands (
  request_id uuid not null references public.listing_transfer_out_requests(id),
  decision text not null check (decision in ('accept', 'decline')),
  response_reason text check (response_reason is null or char_length(response_reason) <= 1000),
  created_at timestamptz not null default now()
);
alter table public.respond_listing_transfer_out_commands enable row level security;
create policy respond_listing_transfer_out_authenticated_insert
  on public.respond_listing_transfer_out_commands for insert to authenticated
  with check ((select auth.uid()) is not null);

create function app_private.process_respond_listing_transfer_out_command()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  actor_person_id uuid;
  transfer public.listing_transfer_out_requests%rowtype;
  target_listing public.listings%rowtype;
  approved_version public.listing_versions%rowtype;
  new_draft_id uuid;
  event_id uuid;
  now_at timestamptz := clock_timestamp();
begin
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then raise exception using errcode = '42501', message = 'Authentication required'; end if;
  select * into transfer from public.listing_transfer_out_requests where id = new.request_id for update;
  if not found or transfer.status <> 'pending' or transfer.recipient_person_id <> actor_person_id then
    raise exception using errcode = '42501', message = 'This transfer is not available to you';
  end if;
  select * into target_listing from public.listings where id = transfer.listing_id for update;
  if not found or target_listing.lifecycle_state <> 'transfer_pending' then
    raise exception using errcode = '55000', message = 'The listing is no longer awaiting transfer';
  end if;

  if new.decision = 'accept' then
    if not exists (select 1 from public.independent_agent_profiles profile where profile.person_id = actor_person_id and profile.status = 'active')
      or exists (select 1 from public.brokerage_memberships membership where membership.person_id = actor_person_id and membership.status in ('active', 'suspended')) then
      raise exception using errcode = '22023', message = 'Your independent-agent account is no longer eligible to receive this listing';
    end if;
    select * into approved_version from public.listing_versions
    where id = target_listing.current_approved_version_id and listing_id = target_listing.id and revision_state = 'approved';
    if not found then raise exception using errcode = '55000', message = 'The approved listing details are unavailable'; end if;
    insert into public.listing_versions (
      listing_id, version_number, based_on_version_id, purpose, property_type, property_subtype,
      requested_lifecycle_state, currency, price, price_period, title, description, bedrooms, bathrooms,
      building_area, land_area, area_unit, visibility, public_location_precision, public_location_label,
      public_location, attributes, content_hash, changed_fields, created_by_person_id
    ) values (
      target_listing.id, (select coalesce(max(version_number), 0) + 1 from public.listing_versions where listing_id = target_listing.id),
      approved_version.id, approved_version.purpose, approved_version.property_type, approved_version.property_subtype,
      'active', approved_version.currency, approved_version.price, approved_version.price_period, approved_version.title,
      approved_version.description, approved_version.bedrooms, approved_version.bathrooms, approved_version.building_area,
      approved_version.land_area, approved_version.area_unit, 'private', approved_version.public_location_precision,
      approved_version.public_location_label, approved_version.public_location, approved_version.attributes,
      approved_version.content_hash, '{}'::text[], actor_person_id
    ) returning id into new_draft_id;
    insert into public.listing_version_media (listing_version_id, listing_id, media_id, position, caption)
    select new_draft_id, listing_id, media_id, position, caption from public.listing_version_media
    where listing_version_id = approved_version.id;
    update public.listing_assignments set brokerage_id = null, status = 'ended', ends_at = now_at, ended_by_person_id = actor_person_id,
      reason = 'Listing transferred to an independent agent'
    where listing_id = target_listing.id and status = 'active';
    update public.listings set brokerage_id = null, independent_owner_person_id = actor_person_id,
      created_by_person_id = actor_person_id, current_assignment_id = null, current_approved_version_id = null,
      lifecycle_state = 'draft', published_at = null, unpublished_at = now_at, lock_version = lock_version + 1, updated_at = now_at
    where id = target_listing.id;
    update public.listing_transfer_out_requests set status = 'accepted', responded_at = now_at,
      responded_by_person_id = actor_person_id, response_reason = nullif(btrim(coalesce(new.response_reason, '')), ''), updated_at = now_at
    where id = transfer.id;
    insert into public.listing_state_events (listing_id, from_state, to_state, source_version_id, actor_person_id, reason, occurred_at)
    values (target_listing.id, 'transfer_pending', 'draft', new_draft_id, actor_person_id, 'Accepted by independent agent', now_at);
    insert into public.audit_events (actor_person_id, effective_role_key, brokerage_id, action, target_type, target_id, source, correlation_id, before_summary, after_summary, occurred_at)
    values (actor_person_id, 'agent', transfer.source_brokerage_id, 'listing.transfer_out_accepted', 'listing_transfer', transfer.id, 'web', gen_random_uuid(),
      jsonb_build_object('listing_id', target_listing.id, 'status', 'pending'), jsonb_build_object('listing_id', target_listing.id, 'status', 'accepted', 'new_draft_id', new_draft_id), now_at)
    returning event_id into event_id;
    insert into public.notifications (source_event_id, person_id, brokerage_id, event_type, title, body_safe, target_type, target_id, created_at)
    values (event_id, transfer.initiated_by_person_id, transfer.source_brokerage_id, 'listing.transfer_out_accepted', 'Listing transfer accepted', 'The receiving independent agent accepted the transfer. The listing is now a private draft under their ownership.', 'listing_transfer', transfer.id, now_at);
  else
    update public.listing_transfer_out_requests set status = 'declined', responded_at = now_at,
      responded_by_person_id = actor_person_id, response_reason = nullif(btrim(coalesce(new.response_reason, '')), ''), updated_at = now_at where id = transfer.id;
    update public.listings set lifecycle_state = 'approved_inactive', published_at = null, unpublished_at = now_at,
      lock_version = lock_version + 1, updated_at = now_at where id = target_listing.id;
    insert into public.listing_state_events (listing_id, from_state, to_state, source_version_id, actor_person_id, reason, occurred_at)
    values (target_listing.id, 'transfer_pending', 'approved_inactive', target_listing.current_approved_version_id, actor_person_id, 'Declined by receiving independent agent', now_at);
    insert into public.audit_events (actor_person_id, effective_role_key, brokerage_id, action, target_type, target_id, source, correlation_id, after_summary, occurred_at)
    values (actor_person_id, 'agent', transfer.source_brokerage_id, 'listing.transfer_out_declined', 'listing_transfer', transfer.id, 'web', gen_random_uuid(),
      jsonb_build_object('listing_id', target_listing.id, 'status', 'declined', 'reason', nullif(btrim(coalesce(new.response_reason, '')), '')), now_at)
    returning event_id into event_id;
    insert into public.notifications (source_event_id, person_id, brokerage_id, event_type, title, body_safe, target_type, target_id, created_at)
    values (event_id, transfer.initiated_by_person_id, transfer.source_brokerage_id, 'listing.transfer_out_declined', 'Listing transfer declined', 'The receiving independent agent declined the transfer. The listing remains with the brokerage and is unpublished.', 'listing_transfer', transfer.id, now_at);
  end if;
  return null;
end;
$$;
create trigger process_respond_listing_transfer_out_command before insert on public.respond_listing_transfer_out_commands
  for each row execute function app_private.process_respond_listing_transfer_out_command();
revoke all on function app_private.process_respond_listing_transfer_out_command() from public, anon, authenticated;
revoke all on public.respond_listing_transfer_out_commands from anon, authenticated;
grant insert on public.respond_listing_transfer_out_commands to authenticated;

commit;
