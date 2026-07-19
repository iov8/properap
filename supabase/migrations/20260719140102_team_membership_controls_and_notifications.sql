begin;

alter table public.brokerage_memberships
  drop constraint if exists brokerage_memberships_status_check;
alter table public.brokerage_memberships
  add constraint brokerage_memberships_status_check
  check (status in ('pending', 'active', 'suspended', 'inactive', 'declined', 'departed'));
create unique index brokerage_memberships_one_current_per_person_idx
  on public.brokerage_memberships (person_id)
  where status in ('active', 'suspended');

alter table public.notifications drop constraint if exists notifications_event_type_check;
alter table public.notifications add constraint notifications_event_type_check check (
  event_type in (
    'listing.draft_created', 'listing.submitted', 'listing.approved',
    'listing.changes_requested', 'listing.rejected', 'inquiry.received',
    'share.received', 'share.removed', 'share.revoked',
    'agent.application_submitted', 'membership.suspended',
    'membership.reactivated', 'membership.removed'
  )
);
alter table public.notifications drop constraint if exists notifications_target_type_check;
alter table public.notifications add constraint notifications_target_type_check
  check (target_type in ('listing', 'inquiry', 'share', 'agent_application', 'brokerage_membership'));

alter table app_private.outbox_events drop constraint if exists outbox_events_aggregate_type_check;
alter table app_private.outbox_events add constraint outbox_events_aggregate_type_check
  check (aggregate_type in ('listing', 'inquiry', 'share', 'agent_application', 'brokerage_membership'));

create table public.membership_status_commands (
  membership_id uuid not null references public.brokerage_memberships(id),
  operation text not null check (operation in ('suspend', 'reactivate', 'remove')),
  reason text not null check (char_length(btrim(reason)) between 3 and 1000)
);
alter table public.membership_status_commands enable row level security;
create policy membership_status_command_authorized_insert
  on public.membership_status_commands for insert to authenticated
  with check (
    exists (
      select 1 from public.brokerage_memberships membership
      where membership.id = membership_id
        and app_private.has_brokerage_permission(membership.brokerage_id, 'agent.manage')
    )
  );

create function app_private.process_membership_status_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid := app_private.current_person_id();
  target_membership public.brokerage_memberships%rowtype;
  actor_effective_role text;
  next_status text;
  event_action text;
  change_time timestamptz := clock_timestamp();
  affected record;
  affected_listing_count integer := 0;
begin
  select * into target_membership
  from public.brokerage_memberships
  where id = new.membership_id
  for update;

  if not found or actor_person_id is null
    or not app_private.has_brokerage_permission(target_membership.brokerage_id, 'agent.manage') then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;
  if target_membership.person_id = actor_person_id then
    raise exception using errcode = '42501', message = 'You cannot change your own brokerage access';
  end if;
  if exists (
    select 1 from public.membership_roles role
    where role.membership_id = target_membership.id and role.role_key = 'broker'
      and role.ends_at is null
  ) then
    raise exception using errcode = '42501', message = 'The principal broker cannot be suspended';
  end if;

  select case when exists (
    select 1 from public.brokerage_memberships membership
    join public.membership_roles role on role.membership_id = membership.id
    where membership.person_id = actor_person_id
      and membership.brokerage_id = target_membership.brokerage_id
      and membership.status = 'active' and role.role_key = 'broker' and role.ends_at is null
  ) then 'broker' else 'broker_staff' end into actor_effective_role;

  if new.operation = 'remove' then
    if target_membership.status not in ('active', 'suspended') then
      raise exception using errcode = '22023', message = 'Only a current team member can be removed';
    end if;
    for affected in
      select assignment.id as assignment_id, listing.id as listing_id,
        listing.lifecycle_state as prior_state
      from public.listing_assignments assignment
      join public.listings listing on listing.id = assignment.listing_id
      where assignment.agent_membership_id = target_membership.id
        and assignment.status = 'active'
      order by listing.id for update of listing, assignment
    loop
      update public.listing_assignments
      set status = 'invalidated', ends_at = greatest(change_time, starts_at + interval '1 microsecond'),
          ended_by_person_id = actor_person_id, reason = 'Representative removed from brokerage'
      where id = affected.assignment_id;
      update public.listings
      set lifecycle_state = 'unassigned', current_assignment_id = null,
          unpublished_at = case when affected.prior_state in ('active', 'under_offer') then change_time else unpublished_at end,
          updated_at = change_time, lock_version = lock_version + 1
      where id = affected.listing_id;
      insert into public.listing_state_events (
        listing_id, from_state, to_state, actor_person_id, reason, occurred_at
      ) values (
        affected.listing_id, affected.prior_state, 'unassigned', actor_person_id,
        'Representative removed from brokerage', change_time
      );
      affected_listing_count := affected_listing_count + 1;
    end loop;
    update public.membership_roles
    set ends_at = greatest(change_time, starts_at + interval '1 microsecond')
    where membership_id = target_membership.id and ends_at is null;
    update public.membership_permissions
    set ends_at = greatest(change_time, starts_at + interval '1 microsecond')
    where membership_id = target_membership.id and ends_at is null;
    update public.brokerage_memberships
    set status = 'departed', ends_at = change_time,
        deactivated_by_person_id = actor_person_id, reason = btrim(new.reason),
        updated_at = change_time, lock_version = lock_version + 1
    where id = target_membership.id;
    update public.professional_sites
    set status = 'paused', updated_at = change_time
    where owner_person_id = target_membership.person_id and site_type = 'agent';
    insert into public.audit_events (
      actor_person_id, effective_role_key, brokerage_id, action,
      target_type, target_id, source, correlation_id, reason,
      before_summary, after_summary
    ) values (
      actor_person_id, actor_effective_role, target_membership.brokerage_id,
      'membership.removed', 'brokerage_membership', target_membership.id,
      'web', gen_random_uuid(), btrim(new.reason),
      jsonb_build_object('status', target_membership.status),
      jsonb_build_object('status', 'departed', 'unassigned_listing_count', affected_listing_count)
    );
    return null;
  end if;

  if new.operation = 'suspend' then
    if target_membership.status <> 'active' then
      raise exception using errcode = '22023', message = 'Only an active member can be suspended';
    end if;
    next_status := 'suspended';
    event_action := 'membership.suspended';
  else
    if target_membership.status <> 'suspended' then
      raise exception using errcode = '22023', message = 'Only a suspended member can be reactivated';
    end if;
    if exists (
      select 1 from public.brokerage_memberships membership
      where membership.person_id = target_membership.person_id
        and membership.status = 'active' and membership.id <> target_membership.id
    ) then
      raise exception using errcode = '23505', message = 'The member already belongs to an active brokerage';
    end if;
    next_status := 'active';
    event_action := 'membership.reactivated';
  end if;

  update public.brokerage_memberships
  set status = next_status,
      reason = btrim(new.reason),
      deactivated_by_person_id = case when next_status = 'suspended' then actor_person_id else null end,
      updated_at = clock_timestamp(), lock_version = lock_version + 1
  where id = target_membership.id;

  update public.professional_sites
  set status = case when next_status = 'suspended' then 'paused' else 'active' end,
      updated_at = clock_timestamp()
  where owner_person_id = target_membership.person_id and site_type = 'agent';

  insert into public.audit_events (
    actor_person_id, effective_role_key, brokerage_id, action,
    target_type, target_id, source, correlation_id, reason,
    before_summary, after_summary
  ) values (
    actor_person_id, actor_effective_role, target_membership.brokerage_id,
    event_action, 'brokerage_membership', target_membership.id,
    'web', gen_random_uuid(), btrim(new.reason),
    jsonb_build_object('status', target_membership.status),
    jsonb_build_object('status', next_status, 'person_id', target_membership.person_id)
  );
  return null;
end;
$$;

create trigger process_membership_status_command
  before insert on public.membership_status_commands
  for each row execute function app_private.process_membership_status_command();

revoke all on function app_private.process_membership_status_command() from public, anon, authenticated;
revoke all on public.membership_status_commands from anon, authenticated;
grant insert on public.membership_status_commands to authenticated;

create function app_private.prepare_suspended_agent_departure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_membership public.brokerage_memberships%rowtype;
begin
  select * into target_membership
  from public.brokerage_memberships where id = new.membership_id for update;
  if found and target_membership.status = 'suspended' then
    if app_private.current_person_id() is null
      or target_membership.person_id = app_private.current_person_id()
      or not app_private.has_brokerage_permission(target_membership.brokerage_id, 'agent.manage') then
      raise exception using errcode = '42501', message = 'Permission denied';
    end if;
    update public.brokerage_memberships
    set status = 'active', updated_at = clock_timestamp(), lock_version = lock_version + 1
    where id = target_membership.id;
  end if;
  return new;
end;
$$;
create trigger a_prepare_suspended_agent_departure
  before insert on public.agent_departure_commands
  for each row execute function app_private.prepare_suspended_agent_departure();
revoke all on function app_private.prepare_suspended_agent_departure() from public, anon, authenticated;

-- Allow removal after a member has first been suspended.
create or replace function app_private.allow_suspended_agent_departure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'departed' then
    update public.professional_sites
    set status = 'paused', updated_at = clock_timestamp()
    where owner_person_id = new.person_id and site_type = 'agent';
  end if;
  return new;
end;
$$;
create trigger pause_departed_agent_site
  after update of status on public.brokerage_memberships
  for each row when (new.status = 'departed')
  execute function app_private.allow_suspended_agent_departure();
revoke all on function app_private.allow_suspended_agent_departure() from public, anon, authenticated;

create function app_private.create_team_workflow_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  recipient_person_id uuid;
  notification_id uuid;
  notification_event text;
  notification_title text;
  notification_body text;
  aggregate_kind text;
begin
  if new.action = 'agent_application.submitted' then
    notification_event := 'agent.application_submitted';
    notification_title := 'New agent application';
    notification_body := 'A person applied to join your brokerage as an agent.';
    aggregate_kind := 'agent_application';
    for recipient in
      select distinct membership.person_id
      from public.brokerage_memberships membership
      where membership.brokerage_id = new.brokerage_id
        and membership.status = 'active'
        and membership.person_id <> new.actor_person_id
        and (
          exists (
            select 1 from public.membership_permissions permission
            where permission.membership_id = membership.id
              and permission.permission_key = 'agent.manage'
              and permission.effect = 'allow' and permission.ends_at is null
          )
          or (
            not exists (
              select 1 from public.membership_permissions permission
              where permission.membership_id = membership.id
                and permission.permission_key = 'agent.manage'
                and permission.effect = 'deny' and permission.ends_at is null
            )
            and exists (
              select 1 from public.membership_roles role
              join public.role_permissions role_permission on role_permission.role_key = role.role_key
              where role.membership_id = membership.id
                and role_permission.permission_key = 'agent.manage'
                and role.ends_at is null
            )
          )
        )
    loop
      insert into public.notifications (
        source_event_id, person_id, brokerage_id, event_type, title,
        body_safe, target_type, target_id, created_at
      ) values (
        new.event_id, recipient.person_id, new.brokerage_id, notification_event,
        notification_title, notification_body, aggregate_kind, new.target_id, new.occurred_at
      ) on conflict (person_id, source_event_id, event_type) do nothing
      returning id into notification_id;
      if notification_id is not null then
        insert into app_private.outbox_events (
          topic, notification_id, aggregate_type, aggregate_id,
          payload
        ) values (
          'notification.email.requested', notification_id, aggregate_kind, new.target_id,
          jsonb_build_object('person_id', recipient.person_id, 'event_type', notification_event)
        );
      end if;
      notification_id := null;
    end loop;
    return new;
  end if;

  if new.action in ('membership.suspended', 'membership.reactivated', 'membership.removed', 'agent.departed') then
    select membership.person_id into recipient_person_id
    from public.brokerage_memberships membership where membership.id = new.target_id;
    if recipient_person_id is null then return new; end if;

    if new.action = 'membership.suspended' then
      notification_event := 'membership.suspended';
      notification_title := 'Brokerage access suspended';
      notification_body := 'Your brokerage access is now read-only. Contact your broker for details.';
    elsif new.action = 'membership.reactivated' then
      notification_event := 'membership.reactivated';
      notification_title := 'Brokerage access restored';
      notification_body := 'Your brokerage access has been restored.';
    else
      notification_event := 'membership.removed';
      notification_title := 'Removed from brokerage team';
      notification_body := 'Your brokerage membership has ended. Your personal CanadaSAP account remains active.';
    end if;

    insert into public.notifications (
      source_event_id, person_id, brokerage_id, event_type, title,
      body_safe, target_type, target_id, created_at
    ) values (
      new.event_id, recipient_person_id, new.brokerage_id, notification_event,
      notification_title, notification_body, 'brokerage_membership', new.target_id, new.occurred_at
    ) on conflict (person_id, source_event_id, event_type) do nothing
    returning id into notification_id;
    if notification_id is not null then
      insert into app_private.outbox_events (topic, notification_id, aggregate_type, aggregate_id, payload)
      values (
        'notification.email.requested', notification_id, 'brokerage_membership', new.target_id,
        jsonb_build_object('person_id', recipient_person_id, 'event_type', notification_event)
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger create_team_workflow_notifications
  after insert on public.audit_events
  for each row execute function app_private.create_team_workflow_notifications();
revoke all on function app_private.create_team_workflow_notifications() from public, anon, authenticated;

comment on table public.membership_status_commands is
  'Write-only command boundary for authorized brokerage suspension and reactivation.';

commit;
