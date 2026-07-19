begin;

create table public.remove_listing_media_commands (
  request_id uuid primary key,
  listing_id uuid not null,
  media_id uuid not null,
  created_at timestamptz not null default now()
);

alter table public.remove_listing_media_commands enable row level security;
create policy remove_listing_media_authenticated_insert
  on public.remove_listing_media_commands for insert to authenticated
  with check ((select auth.uid()) is not null);

create function app_private.process_remove_listing_media_command()
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
  removed_position smallint;
  actor_effective_role text;
begin
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select * into target_listing from public.listings where id = new.listing_id for update;
  if not found then raise exception using errcode = '42501', message = 'Permission denied'; end if;
  if target_listing.lifecycle_state <> 'draft' then
    raise exception using errcode = '55000', message = 'Images can only be removed from an editable draft';
  end if;

  select * into actor_membership from public.brokerage_memberships
  where person_id = actor_person_id and brokerage_id = target_listing.brokerage_id and status = 'active'
  limit 1;
  if not found or not (
    target_listing.created_by_person_id = actor_person_id
    or app_private.has_brokerage_permission(target_listing.brokerage_id, 'listing.manage')
  ) then raise exception using errcode = '42501', message = 'Permission denied'; end if;

  select id into target_version_id from public.listing_versions
  where listing_id = target_listing.id and revision_state = 'working_draft'
  order by version_number desc limit 1 for update;
  if target_version_id is null then raise exception using errcode = '55000', message = 'Editable listing version not found'; end if;

  select position into removed_position from public.listing_version_media
  where listing_version_id = target_version_id and media_id = new.media_id;
  if removed_position is null then raise exception using errcode = '22023', message = 'This image is not attached to the editable draft'; end if;

  set constraints listing_version_media_listing_version_id_position_key deferred;
  delete from public.listing_version_media
  where listing_version_id = target_version_id and media_id = new.media_id;
  update public.listing_version_media
  set position = position - 1
  where listing_version_id = target_version_id and position > removed_position;

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
    'listing.photo_removed', 'listing', target_listing.id, 'web', new.request_id,
    jsonb_build_object('media_id', new.media_id, 'position', removed_position, 'version_id', target_version_id)
  );
  return null;
end;
$$;

create trigger process_remove_listing_media_command
  before insert on public.remove_listing_media_commands
  for each row execute function app_private.process_remove_listing_media_command();

revoke all on function app_private.process_remove_listing_media_command() from public, anon, authenticated;
revoke all on public.remove_listing_media_commands from anon, authenticated;
grant insert on public.remove_listing_media_commands to authenticated;

comment on table public.remove_listing_media_commands is
  'Write-only command boundary that removes a photo from the current editable listing version without changing retained prior versions.';

commit;
