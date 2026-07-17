begin;

alter table public.property_addresses
  add column created_by_brokerage_id uuid not null references public.brokerages(id),
  add column created_by_person_id uuid not null references public.people(id);

alter table public.properties
  add column created_by_person_id uuid not null references public.people(id);

create index property_addresses_creator_brokerage_idx
  on public.property_addresses (created_by_brokerage_id, created_at desc);
create index property_addresses_creator_person_idx
  on public.property_addresses (created_by_person_id, created_at desc);
create index properties_creator_person_idx
  on public.properties (created_by_person_id, created_at desc);

create function app_private.can_read_listing_private(target_listing_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.listings as listing
    where listing.id = target_listing_id
      and app_private.is_active_brokerage_member(listing.brokerage_id)
      and (
        app_private.has_brokerage_permission(listing.brokerage_id, 'listing.manage')
        or app_private.has_brokerage_permission(listing.brokerage_id, 'listing.review')
        or app_private.has_brokerage_permission(listing.brokerage_id, 'listing.reassign')
        or (
          listing.created_by_person_id = app_private.current_person_id()
          and listing.lifecycle_state in ('draft', 'pending_initial_approval')
        )
        or exists (
          select 1
          from public.listing_assignments as assignment
          join public.brokerage_memberships as membership
            on membership.id = assignment.agent_membership_id
          where assignment.listing_id = listing.id
            and assignment.status = 'active'
            and membership.person_id = app_private.current_person_id()
            and membership.status = 'active'
        )
      )
  )
$$;

create function app_private.can_read_property_private(target_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.properties as property
    where property.id = target_property_id
      and (
        (
          property.created_by_person_id = app_private.current_person_id()
          and app_private.is_active_brokerage_member(property.created_by_brokerage_id)
        )
        or app_private.has_brokerage_permission(property.created_by_brokerage_id, 'listing.manage')
        or app_private.has_brokerage_permission(property.created_by_brokerage_id, 'listing.review')
        or exists (
          select 1 from public.listings as listing
          where listing.property_id = property.id
            and app_private.can_read_listing_private(listing.id)
        )
      )
  )
$$;

create function app_private.can_read_address_private(target_address_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.property_addresses as address
    where address.id = target_address_id
      and (
        (
          address.created_by_person_id = app_private.current_person_id()
          and app_private.is_active_brokerage_member(address.created_by_brokerage_id)
        )
        or app_private.has_brokerage_permission(address.created_by_brokerage_id, 'listing.manage')
        or app_private.has_brokerage_permission(address.created_by_brokerage_id, 'listing.review')
        or exists (
          select 1 from public.properties as property
          where property.address_id = address.id
            and app_private.can_read_property_private(property.id)
        )
      )
  )
$$;

create function app_private.can_read_listing_version_private(target_version_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.listing_versions as version
    where version.id = target_version_id
      and app_private.can_read_listing_private(version.listing_id)
  )
$$;

revoke all on function app_private.can_read_listing_private(uuid) from public, anon, authenticated;
revoke all on function app_private.can_read_property_private(uuid) from public, anon, authenticated;
revoke all on function app_private.can_read_address_private(uuid) from public, anon, authenticated;
revoke all on function app_private.can_read_listing_version_private(uuid) from public, anon, authenticated;

grant execute on function app_private.can_read_listing_private(uuid) to authenticated;
grant execute on function app_private.can_read_property_private(uuid) to authenticated;
grant execute on function app_private.can_read_address_private(uuid) to authenticated;
grant execute on function app_private.can_read_listing_version_private(uuid) to authenticated;

create policy administrative_areas_public_read on public.administrative_areas
  for select to anon, authenticated using (true);
create policy localities_public_read on public.localities
  for select to anon, authenticated using (true);

create policy property_addresses_private_read on public.property_addresses
  for select to authenticated
  using (app_private.can_read_address_private(id));
create policy properties_private_read on public.properties
  for select to authenticated
  using (app_private.can_read_property_private(id));
create policy listings_private_read on public.listings
  for select to authenticated
  using (app_private.can_read_listing_private(id));
create policy listing_assignments_private_read on public.listing_assignments
  for select to authenticated
  using (app_private.can_read_listing_private(listing_id));
create policy listing_versions_private_read on public.listing_versions
  for select to authenticated
  using (app_private.can_read_listing_private(listing_id));
create policy listing_reviews_private_read on public.listing_reviews
  for select to authenticated
  using (app_private.can_read_listing_version_private(listing_version_id));
create policy listing_state_events_private_read on public.listing_state_events
  for select to authenticated
  using (app_private.can_read_listing_private(listing_id));

grant select on public.administrative_areas, public.localities to anon, authenticated;
grant select on public.property_addresses, public.properties, public.listings,
  public.listing_assignments, public.listing_versions, public.listing_reviews,
  public.listing_state_events to authenticated;

comment on function app_private.can_read_listing_private(uuid) is
  'Tenant-scoped private listing authorization used by RLS; ordinary agents are limited to represented or early created work.';

commit;
