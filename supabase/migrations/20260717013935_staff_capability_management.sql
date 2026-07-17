begin;

-- Capability changes use the same insert-only command boundary as onboarding.
-- The trigger validates principal-broker authority and returns null, so command
-- payloads are never retained or exposed through the Data API.
create table public.membership_permission_commands (
  membership_id uuid not null references public.brokerage_memberships(id),
  permission_key text not null references public.permission_definitions(key),
  operation text not null check (operation in ('grant', 'revoke')),
  reason text check (reason is null or char_length(reason) <= 1000)
);

alter table public.membership_permission_commands enable row level security;

create policy membership_permission_command_authenticated_insert
  on public.membership_permission_commands
  for insert to authenticated
  with check (app_private.current_person_id() is not null);

create function app_private.process_membership_permission_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  target_membership public.brokerage_memberships%rowtype;
  active_effect text;
  normalized_reason text;
begin
  actor_person_id := app_private.current_person_id();
  normalized_reason := nullif(btrim(coalesce(new.reason, '')), '');

  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select * into target_membership
  from public.brokerage_memberships
  where id = new.membership_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Membership not found';
  end if;

  if not exists (
    select 1
    from public.brokerage_memberships as actor_membership
    join public.membership_roles as actor_role
      on actor_role.membership_id = actor_membership.id
    where actor_membership.person_id = actor_person_id
      and actor_membership.brokerage_id = target_membership.brokerage_id
      and actor_membership.status = 'active'
      and actor_role.role_key = 'broker'
      and actor_role.starts_at <= now()
      and (actor_role.ends_at is null or actor_role.ends_at > now())
  ) then
    raise exception using errcode = '42501', message = 'Only the principal broker can manage staff capabilities';
  end if;

  if target_membership.status <> 'active'
    or not exists (
      select 1
      from public.membership_roles as target_role
      where target_role.membership_id = target_membership.id
        and target_role.role_key = 'broker_staff'
        and target_role.starts_at <= now()
        and (target_role.ends_at is null or target_role.ends_at > now())
    )
    or exists (
      select 1
      from public.membership_roles as target_role
      where target_role.membership_id = target_membership.id
        and target_role.role_key = 'broker'
        and target_role.starts_at <= now()
        and (target_role.ends_at is null or target_role.ends_at > now())
    )
  then
    raise exception using errcode = '22023', message = 'Capabilities can be assigned only to active broker staff';
  end if;

  if new.permission_key <> all (array[
    'listing.review',
    'listing.manage',
    'listing.reassign',
    'agent.manage',
    'staff.manage_limited',
    'brokerage.profile',
    'inquiry.manage',
    'report.view',
    'audit.view',
    'billing.view',
    'integration.manage'
  ]::text[]) then
    raise exception using errcode = '22023', message = 'Capability is not delegable';
  end if;

  select permission.effect into active_effect
  from public.membership_permissions as permission
  where permission.membership_id = target_membership.id
    and permission.permission_key = new.permission_key
    and permission.starts_at <= now()
    and (permission.ends_at is null or permission.ends_at > now())
  for update;

  if new.operation = 'grant' then
    if active_effect = 'allow' then
      return null;
    end if;

    if active_effect is not null then
      update public.membership_permissions
      set ends_at = greatest(clock_timestamp(), starts_at + interval '1 microsecond')
      where membership_id = target_membership.id
        and permission_key = new.permission_key
        and ends_at is null;
    end if;

    insert into public.membership_permissions (
      membership_id, permission_key, effect, granted_by_person_id, reason
    ) values (
      target_membership.id, new.permission_key, 'allow', actor_person_id,
      normalized_reason
    );

    insert into public.audit_events (
      actor_person_id, effective_role_key, brokerage_id, action,
      target_type, target_id, source, correlation_id, reason,
      before_summary, after_summary
    ) values (
      actor_person_id, 'broker', target_membership.brokerage_id,
      'membership_permission.granted', 'membership_permission',
      target_membership.id, 'web', gen_random_uuid(), normalized_reason,
      jsonb_build_object('permission_key', new.permission_key, 'effect', active_effect),
      jsonb_build_object('permission_key', new.permission_key, 'effect', 'allow')
    );
  else
    if active_effect is distinct from 'allow' then
      return null;
    end if;

    update public.membership_permissions
    set ends_at = greatest(clock_timestamp(), starts_at + interval '1 microsecond')
    where membership_id = target_membership.id
      and permission_key = new.permission_key
      and effect = 'allow'
      and ends_at is null;

    insert into public.audit_events (
      actor_person_id, effective_role_key, brokerage_id, action,
      target_type, target_id, source, correlation_id, reason,
      before_summary, after_summary
    ) values (
      actor_person_id, 'broker', target_membership.brokerage_id,
      'membership_permission.revoked', 'membership_permission',
      target_membership.id, 'web', gen_random_uuid(), normalized_reason,
      jsonb_build_object('permission_key', new.permission_key, 'effect', 'allow'),
      jsonb_build_object('permission_key', new.permission_key, 'effect', null)
    );
  end if;

  return null;
end;
$$;

create trigger process_membership_permission_command
  before insert on public.membership_permission_commands
  for each row execute function app_private.process_membership_permission_command();

revoke all on function app_private.process_membership_permission_command()
  from public, anon, authenticated;

revoke all on public.membership_permission_commands from anon, authenticated;
grant insert on public.membership_permission_commands to authenticated;

comment on table public.membership_permission_commands is
  'Write-only principal-broker capability command boundary; rows are never persisted.';

commit;
