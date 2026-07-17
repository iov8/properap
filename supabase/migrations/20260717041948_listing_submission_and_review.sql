begin;

create table public.submit_listing_version_commands (
  request_id uuid not null,
  listing_id uuid not null,
  listing_version_id uuid not null,
  expected_lock_version integer not null check (expected_lock_version > 0)
);

alter table public.submit_listing_version_commands enable row level security;
create policy submit_listing_version_authenticated_insert
  on public.submit_listing_version_commands for insert to authenticated
  with check ((select auth.uid()) is not null);

create function app_private.process_submit_listing_version_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  actor_membership public.brokerage_memberships%rowtype;
  target_listing public.listings%rowtype;
  target_version public.listing_versions%rowtype;
  submitted_at_value timestamptz := clock_timestamp();
  snapshot_hash text;
  ready_media_count integer;
  media_snapshot jsonb;
  actor_effective_role text;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Active person required';
  end if;

  select * into target_listing from public.listings
  where id = new.listing_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;

  select * into target_version from public.listing_versions
  where id = new.listing_version_id and listing_id = target_listing.id
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;

  if target_listing.lifecycle_state = 'pending_initial_approval'
    and target_version.revision_state = 'submitted'
    and target_version.submitted_by_person_id = actor_person_id then
    return null;
  end if;
  if target_listing.lifecycle_state <> 'draft' or target_version.revision_state <> 'working_draft' then
    raise exception using errcode = '55000', message = 'Only the current working draft can be submitted';
  end if;
  if target_listing.lock_version <> new.expected_lock_version then
    raise exception using errcode = '40001', message = 'Draft changed since it was opened';
  end if;

  select membership.* into actor_membership
  from public.brokerage_memberships as membership
  join public.listing_assignments as assignment
    on assignment.agent_membership_id = membership.id
  where assignment.id = target_listing.current_assignment_id
    and assignment.listing_id = target_listing.id
    and assignment.status = 'active'
    and membership.person_id = actor_person_id
    and membership.brokerage_id = target_listing.brokerage_id
    and membership.status = 'active';
  if not found or not app_private.has_brokerage_permission(target_listing.brokerage_id, 'listing.submit') then
    raise exception using errcode = '42501', message = 'Only the active listing representative can submit this draft';
  end if;

  if exists (
    select 1 from public.listing_version_media as link
    join public.listing_media as media on media.id = link.media_id
    where link.listing_version_id = target_version.id
      and media.status in ('awaiting_upload', 'validating')
  ) then
    raise exception using errcode = '55000', message = 'Wait for all image checks to finish before submitting';
  end if;

  delete from public.listing_version_media as link
  using public.listing_media as media
  where link.media_id = media.id
    and link.listing_version_id = target_version.id
    and media.status in ('rejected', 'removed');

  select count(*), coalesce(jsonb_agg(jsonb_build_object(
    'media_id', media.id,
    'position', link.position,
    'mime_type', media.detected_mime_type,
    'byte_size', media.actual_byte_size,
    'width', media.width,
    'height', media.height
  ) order by link.position), '[]'::jsonb)
  into ready_media_count, media_snapshot
  from public.listing_version_media as link
  join public.listing_media as media on media.id = link.media_id
  where link.listing_version_id = target_version.id and media.status = 'ready';
  if ready_media_count < 1 then
    raise exception using errcode = '22023', message = 'Add at least one validated property image before submitting';
  end if;

  snapshot_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'version', to_jsonb(target_version) - array[
      'revision_state','submitted_by_person_id','submitted_at','frozen_at',
      'approved_at','content_hash','created_at'
    ],
    'media', media_snapshot,
    'property_id', target_listing.property_id,
    'assignment_id', target_listing.current_assignment_id
  )::text, 'UTF8'), 'sha256'), 'hex');

  update public.listing_versions
  set revision_state = 'submitted', submitted_by_person_id = actor_person_id,
      submitted_at = submitted_at_value, frozen_at = submitted_at_value,
      content_hash = snapshot_hash
  where id = target_version.id;

  update public.listings
  set lifecycle_state = 'pending_initial_approval', lock_version = lock_version + 1,
      updated_at = submitted_at_value
  where id = target_listing.id;

  insert into public.listing_state_events (
    listing_id, from_state, to_state, source_version_id, actor_person_id,
    reason, occurred_at
  ) values (
    target_listing.id, 'draft', 'pending_initial_approval', target_version.id,
    actor_person_id, 'Initial listing submitted for brokerage approval', submitted_at_value
  );

  select case when exists (
    select 1 from public.membership_roles
    where membership_id = actor_membership.id and role_key = 'broker'
      and starts_at <= now() and (ends_at is null or ends_at > now())
  ) then 'broker' else 'agent' end into actor_effective_role;

  insert into public.audit_events (
    actor_person_id, effective_role_key, brokerage_id, action, target_type,
    target_id, source, correlation_id, after_summary, occurred_at
  ) values (
    actor_person_id, actor_effective_role, target_listing.brokerage_id,
    'listing.submitted', 'listing', target_listing.id, 'web', new.request_id,
    jsonb_build_object(
      'version_id', target_version.id,
      'version_number', target_version.version_number,
      'media_count', ready_media_count,
      'visibility_request', target_version.visibility
    ), submitted_at_value
  );

  return null;
end;
$$;

create trigger process_submit_listing_version_command
  before insert on public.submit_listing_version_commands
  for each row execute function app_private.process_submit_listing_version_command();

revoke all on function app_private.process_submit_listing_version_command()
  from public, anon, authenticated;
revoke all on public.submit_listing_version_commands from anon, authenticated;
grant insert on public.submit_listing_version_commands to authenticated;

create table public.decide_listing_review_commands (
  request_id uuid not null,
  review_id uuid not null,
  listing_id uuid not null,
  listing_version_id uuid not null,
  decision text not null check (decision in ('approved', 'changes_requested', 'rejected')),
  comment text check (comment is null or char_length(comment) <= 4000)
);

alter table public.decide_listing_review_commands enable row level security;
create policy decide_listing_review_authenticated_insert
  on public.decide_listing_review_commands for insert to authenticated
  with check ((select auth.uid()) is not null);

create function app_private.process_decide_listing_review_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  actor_membership public.brokerage_memberships%rowtype;
  target_listing public.listings%rowtype;
  target_version public.listing_versions%rowtype;
  decision_time timestamptz := clock_timestamp();
  normalized_comment text;
  self_approval boolean;
  next_state text;
  actor_effective_role text;
  new_working_version_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Active person required';
  end if;

  select * into target_listing from public.listings
  where id = new.listing_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;

  select * into actor_membership
  from public.brokerage_memberships
  where brokerage_id = target_listing.brokerage_id
    and person_id = actor_person_id and status = 'active'
  limit 1;
  if not found or not app_private.has_brokerage_permission(target_listing.brokerage_id, 'listing.review') then
    raise exception using errcode = '42501', message = 'Listing review authority is required';
  end if;

  if exists (
    select 1 from public.listing_reviews
    where listing_version_id = new.listing_version_id
      and reviewer_person_id = actor_person_id and decision = new.decision
  ) then
    return null;
  end if;

  select * into target_version from public.listing_versions
  where id = new.listing_version_id and listing_id = target_listing.id
  for update;
  if not found or target_listing.lifecycle_state <> 'pending_initial_approval'
    or target_version.revision_state <> 'submitted' then
    raise exception using errcode = '55000', message = 'This submission is no longer awaiting a decision';
  end if;

  normalized_comment := nullif(btrim(coalesce(new.comment, '')), '');
  if new.decision <> 'approved' and normalized_comment is null then
    raise exception using errcode = '22023', message = 'A clear reviewer comment is required';
  end if;
  if new.decision = 'approved' then
    if target_listing.current_assignment_id is null or not exists (
      select 1 from public.listing_assignments as assignment
      join public.brokerage_memberships as membership
        on membership.id = assignment.agent_membership_id
      join public.membership_roles as role
        on role.membership_id = membership.id and role.role_key = 'agent'
      where assignment.id = target_listing.current_assignment_id
        and assignment.status = 'active'
        and membership.status = 'active'
        and membership.brokerage_id = target_listing.brokerage_id
        and role.starts_at <= now() and (role.ends_at is null or role.ends_at > now())
    ) then
      raise exception using errcode = '55000', message = 'Approval requires an active listing representative';
    end if;
    if not exists (
      select 1 from public.listing_version_media as link
      join public.listing_media as media on media.id = link.media_id
      where link.listing_version_id = target_version.id and media.status = 'ready'
    ) then
      raise exception using errcode = '55000', message = 'Approval requires validated listing media';
    end if;
  end if;

  self_approval := actor_person_id = target_version.submitted_by_person_id;
  insert into public.listing_reviews (
    id, listing_version_id, reviewer_person_id, reviewer_membership_id,
    decision, comment, is_self_approval, decided_at
  ) values (
    new.review_id, target_version.id, actor_person_id, actor_membership.id,
    new.decision, normalized_comment, self_approval, decision_time
  );

  update public.listing_versions
  set revision_state = new.decision,
      approved_at = case when new.decision = 'approved' then decision_time else null end
  where id = target_version.id;

  if new.decision = 'changes_requested' then
    insert into public.listing_versions (
      listing_id, version_number, based_on_version_id, purpose, property_type,
      property_subtype, requested_lifecycle_state, currency, price, price_period,
      title, description, bedrooms, bathrooms, building_area, land_area,
      area_unit, visibility, public_location_precision, public_location_label,
      public_location, attributes, content_hash, changed_fields,
      created_by_person_id
    ) select
      version.listing_id,
      (select max(existing.version_number) + 1 from public.listing_versions as existing
        where existing.listing_id = version.listing_id),
      version.id, version.purpose, version.property_type, version.property_subtype,
      version.requested_lifecycle_state, version.currency, version.price,
      version.price_period, version.title, version.description, version.bedrooms,
      version.bathrooms, version.building_area, version.land_area, version.area_unit,
      version.visibility, version.public_location_precision,
      version.public_location_label, version.public_location, version.attributes,
      version.content_hash, '{}'::text[], version.submitted_by_person_id
    from public.listing_versions as version where version.id = target_version.id
    returning id into new_working_version_id;

    insert into public.listing_version_media (
      listing_version_id, listing_id, media_id, position, caption
    ) select new_working_version_id, listing_id, media_id, position, caption
    from public.listing_version_media
    where listing_version_id = target_version.id;
  end if;

  next_state := case when new.decision = 'approved' then 'approved_inactive' else 'draft' end;
  update public.listings
  set lifecycle_state = next_state,
      current_approved_version_id = case
        when new.decision = 'approved' then target_version.id
        else current_approved_version_id
      end,
      lock_version = lock_version + 1,
      updated_at = decision_time
  where id = target_listing.id;

  insert into public.listing_state_events (
    listing_id, from_state, to_state, source_version_id, actor_person_id,
    reason, occurred_at
  ) values (
    target_listing.id, 'pending_initial_approval', next_state, target_version.id,
    actor_person_id,
    case new.decision
      when 'approved' then 'Brokerage approved initial listing content; publication remains inactive'
      when 'changes_requested' then 'Brokerage requested listing corrections'
      else 'Brokerage rejected the listing submission'
    end,
    decision_time
  );

  select case when exists (
    select 1 from public.membership_roles
    where membership_id = actor_membership.id and role_key = 'broker'
      and starts_at <= now() and (ends_at is null or ends_at > now())
  ) then 'broker' else 'broker_staff' end into actor_effective_role;

  insert into public.audit_events (
    actor_person_id, effective_role_key, brokerage_id, action, target_type,
    target_id, source, correlation_id, reason, before_summary, after_summary,
    occurred_at
  ) values (
    actor_person_id, actor_effective_role, target_listing.brokerage_id,
    'listing.reviewed', 'listing', target_listing.id, 'web', new.request_id,
    normalized_comment,
    jsonb_build_object('lifecycle_state', target_listing.lifecycle_state,
      'version_state', target_version.revision_state),
    jsonb_build_object('lifecycle_state', next_state, 'decision', new.decision,
      'version_id', target_version.id, 'self_approval', self_approval,
      'new_working_version_id', new_working_version_id),
    decision_time
  );

  return null;
end;
$$;

create trigger process_decide_listing_review_command
  before insert on public.decide_listing_review_commands
  for each row execute function app_private.process_decide_listing_review_command();

revoke all on function app_private.process_decide_listing_review_command()
  from public, anon, authenticated;
revoke all on public.decide_listing_review_commands from anon, authenticated;
grant insert on public.decide_listing_review_commands to authenticated;

comment on table public.submit_listing_version_commands is
  'Write-only atomic boundary for freezing an agent draft and entering brokerage review.';
comment on table public.decide_listing_review_commands is
  'Write-only atomic boundary for brokerage approval, correction requests, or rejection.';

commit;
