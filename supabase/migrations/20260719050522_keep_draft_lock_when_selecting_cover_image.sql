begin;

create or replace function app_private.process_select_listing_cover_media_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  actor_membership public.brokerage_memberships%rowtype;
  target_listing public.listings%rowtype;
  target_version_id uuid;
  current_cover_id uuid;
  selected_position smallint;
  actor_effective_role text;
begin
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select * into target_listing from public.listings where id = new.listing_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;

  select * into actor_membership from public.brokerage_memberships
  where person_id = actor_person_id and brokerage_id = target_listing.brokerage_id and status = 'active'
  limit 1;
  if not found or not (
    target_listing.created_by_person_id = actor_person_id
    or app_private.has_brokerage_permission(target_listing.brokerage_id, 'listing.manage')
  ) then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;
  if target_listing.lifecycle_state <> 'draft' then
    raise exception using errcode = '55000', message = 'Choose a cover photo before submitting the draft';
  end if;

  select id into target_version_id from public.listing_versions
  where listing_id = target_listing.id and revision_state = 'working_draft'
  order by version_number desc limit 1 for update;
  if target_version_id is null then
    raise exception using errcode = '55000', message = 'Editable listing version not found';
  end if;

  select link.position into selected_position
  from public.listing_version_media as link
  join public.listing_media as media on media.id = link.media_id
  where link.listing_version_id = target_version_id
    and link.media_id = new.media_id and media.status = 'ready';
  if selected_position is null then
    raise exception using errcode = '22023', message = 'Choose a validated image attached to this draft';
  end if;

  select media_id into current_cover_id from public.listing_version_media
  where listing_version_id = target_version_id and position = 1;
  if current_cover_id = new.media_id then
    return null;
  end if;

  set constraints listing_version_media_listing_version_id_position_key deferred;
  update public.listing_version_media
  set position = case
    when media_id = new.media_id then 1
    when media_id = current_cover_id then selected_position
    else position
  end
  where listing_version_id = target_version_id and media_id in (new.media_id, current_cover_id);

  select case when exists (
    select 1 from public.membership_roles
    where membership_id = actor_membership.id and role_key = 'broker'
      and starts_at <= now() and (ends_at is null or ends_at > now())
  ) then 'broker' else 'agent' end into actor_effective_role;

  insert into public.audit_events (
    actor_person_id, effective_role_key, brokerage_id, action, target_type,
    target_id, source, correlation_id, after_summary
  ) values (
    actor_person_id, actor_effective_role, target_listing.brokerage_id,
    'listing.cover_photo_selected', 'listing', target_listing.id, 'web', new.request_id,
    jsonb_build_object('media_id', new.media_id, 'previous_cover_media_id', current_cover_id)
  );
  return null;
end;
$$;

commit;
