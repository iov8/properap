begin;

-- An independent agent cannot operate in both ownership modes at once. When
-- an active agent role is added to a brokerage membership, each independent
-- record becomes a private brokerage draft assigned to that new membership.
-- This preserves the historical independent version, removes public display,
-- and requires the brokerage's normal approval before re-publication.
create or replace function app_private.transfer_independent_listings_on_agent_join()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  joining_membership public.brokerage_memberships%rowtype;
  source_listing public.listings%rowtype;
  source_version public.listing_versions%rowtype;
  copied_version_id uuid;
  assignment_id uuid;
  source_property public.properties%rowtype;
  target_property_id uuid;
  event_id uuid;
  now_at timestamptz := clock_timestamp();
begin
  if new.role_key <> 'agent' or new.ends_at is not null then
    return new;
  end if;

  select * into joining_membership
  from public.brokerage_memberships
  where id = new.membership_id and status = 'active';
  if not found or not exists (
    select 1 from public.independent_agent_profiles
    where person_id = joining_membership.person_id and status = 'active'
  ) then
    return new;
  end if;

  for source_listing in
    select * from public.listings
    where independent_owner_person_id = joining_membership.person_id
    for update
  loop
    select * into source_version
    from public.listing_versions
    where listing_id = source_listing.id
      and revision_state in ('working_draft', 'approved')
    order by case when revision_state = 'working_draft' then 0 else 1 end, version_number desc
    limit 1;
    if not found then
      continue;
    end if;

    select * into source_property from public.properties where id = source_listing.property_id for update;
    select id into target_property_id from public.properties
    where created_by_brokerage_id = joining_membership.brokerage_id
      and address_fingerprint = source_property.address_fingerprint
    limit 1;
    if target_property_id is null then
      update public.properties
      set created_by_brokerage_id = joining_membership.brokerage_id, updated_at = now_at
      where id = source_property.id;
      update public.property_addresses
      set created_by_brokerage_id = joining_membership.brokerage_id, updated_at = now_at
      where id = source_property.address_id;
      target_property_id := source_property.id;
    end if;

    if source_version.revision_state <> 'working_draft' then
      insert into public.listing_versions (
        listing_id, version_number, based_on_version_id, purpose, property_type,
        property_subtype, requested_lifecycle_state, currency, price, price_period,
        title, description, bedrooms, bathrooms, building_area, land_area, area_unit,
        visibility, public_location_precision, public_location_label, public_location,
        attributes, content_hash, changed_fields, created_by_person_id
      ) values (
        source_listing.id,
        (select coalesce(max(version_number), 0) + 1 from public.listing_versions where listing_id = source_listing.id),
        source_version.id, source_version.purpose, source_version.property_type,
        source_version.property_subtype, null, source_version.currency, source_version.price, source_version.price_period,
        source_version.title, source_version.description, source_version.bedrooms, source_version.bathrooms,
        source_version.building_area, source_version.land_area, source_version.area_unit,
        source_version.visibility, source_version.public_location_precision, source_version.public_location_label,
        source_version.public_location, source_version.attributes, source_version.content_hash,
        '{}'::text[], joining_membership.person_id
      ) returning id into copied_version_id;
      insert into public.listing_version_media (listing_version_id, listing_id, media_id, position, caption)
      select copied_version_id, listing_id, media_id, position, caption
      from public.listing_version_media where listing_version_id = source_version.id;
    else
      copied_version_id := source_version.id;
    end if;

    insert into public.listing_assignments (
      listing_id, brokerage_id, historical_brokerage_id, agent_membership_id,
      status, starts_at, assigned_by_person_id, reason
    ) values (
      source_listing.id, joining_membership.brokerage_id, joining_membership.brokerage_id,
      joining_membership.id, 'active', now_at, joining_membership.approved_by_person_id,
      'Independent listing brought into brokerage ownership'
    ) returning id into assignment_id;

    update public.listings
    set brokerage_id = joining_membership.brokerage_id,
        independent_owner_person_id = null,
        property_id = target_property_id,
        current_assignment_id = assignment_id,
        current_approved_version_id = null,
        lifecycle_state = 'draft', published_at = null, unpublished_at = now_at,
        lock_version = lock_version + 1, updated_at = now_at
    where id = source_listing.id;

    insert into public.listing_state_events (
      listing_id, from_state, to_state, source_version_id, actor_person_id, reason, occurred_at
    ) values (
      source_listing.id, source_listing.lifecycle_state, 'draft', copied_version_id,
      joining_membership.person_id, 'Independent listing moved into brokerage review', now_at
    );
    insert into public.audit_events (
      actor_person_id, effective_role_key, brokerage_id, action, target_type, target_id,
      source, correlation_id, before_summary, after_summary, occurred_at
    ) values (
      joining_membership.person_id, 'agent', joining_membership.brokerage_id,
      'listing.transferred_into_brokerage', 'listing', source_listing.id, 'system', gen_random_uuid(),
      jsonb_build_object('ownership', 'independent', 'lifecycle_state', source_listing.lifecycle_state),
      jsonb_build_object('ownership', 'brokerage', 'lifecycle_state', 'draft', 'membership_id', joining_membership.id), now_at
    ) returning event_id into event_id;
    insert into public.notifications (
      source_event_id, person_id, brokerage_id, event_type, title, body_safe, target_type, target_id, created_at
    ) values (
      event_id, joining_membership.person_id, joining_membership.brokerage_id,
      'listing.saved_listing_updated', 'Independent listing moved to brokerage review',
      'Your listing is now a private brokerage draft. Submit it to the brokerage when you are ready for approval.',
      'listing', source_listing.id, now_at
    );
  end loop;

  update public.independent_agent_profiles
  set status = 'inactive', deactivated_at = now_at, updated_at = now_at
  where person_id = joining_membership.person_id and status = 'active';
  return new;
end;
$$;

drop trigger if exists transfer_independent_listings_on_agent_join on public.membership_roles;
create trigger transfer_independent_listings_on_agent_join
  after insert on public.membership_roles
  for each row execute function app_private.transfer_independent_listings_on_agent_join();

revoke all on function app_private.transfer_independent_listings_on_agent_join() from public, anon, authenticated;

commit;
