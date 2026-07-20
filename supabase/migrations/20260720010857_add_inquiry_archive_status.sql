begin;

alter table public.inquiries
  add column if not exists archived_at timestamptz;

alter table public.inquiries
  drop constraint if exists inquiries_status_check;
alter table public.inquiries
  add constraint inquiries_status_check
  check (status in ('new', 'in_progress', 'closed', 'archived'));

alter table public.inquiries
  drop constraint if exists inquiries_check;
alter table public.inquiries
  add constraint inquiries_closed_timestamp_check
  check ((status = 'closed') = (closed_at is not null));

alter table public.inquiries
  add constraint inquiries_archived_timestamp_check
  check ((status = 'archived') = (archived_at is not null));

alter table public.inquiry_status_commands
  drop constraint if exists inquiry_status_commands_operation_check;
alter table public.inquiry_status_commands
  add constraint inquiry_status_commands_operation_check
  check (operation in ('claim', 'close', 'reopen', 'archive', 'restore'));

create or replace function app_private.process_inquiry_status_command()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid;
  target_inquiry public.inquiries%rowtype;
  prior_status text;
  next_status text;
  changed_at timestamptz := clock_timestamp();
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  actor_person_id := app_private.current_person_id();
  if actor_person_id is null then
    raise exception using errcode = '42501', message = 'Active person required';
  end if;

  select * into target_inquiry
  from public.inquiries
  where id = new.inquiry_id
  for update;

  if not found
    or target_inquiry.selected_agent_person_id <> actor_person_id
    or not exists (
      select 1
      from public.brokerage_memberships membership
      join public.membership_roles role
        on role.membership_id = membership.id
       and role.brokerage_id = membership.brokerage_id
      where membership.person_id = actor_person_id
        and membership.brokerage_id = target_inquiry.brokerage_id
        and membership.status = 'active'
        and role.role_key = 'agent'
        and role.starts_at <= now()
        and (role.ends_at is null or role.ends_at > now())
    ) then
    raise exception using errcode = '42501', message = 'Inquiry not found';
  end if;

  prior_status := target_inquiry.status;
  next_status := case new.operation
    when 'claim' then 'in_progress'
    when 'close' then 'closed'
    when 'reopen' then 'in_progress'
    when 'archive' then 'archived'
    when 'restore' then 'in_progress'
  end;

  update public.inquiries
  set status = next_status,
      first_viewed_at = case
        when new.operation = 'claim' then coalesce(first_viewed_at, changed_at)
        else first_viewed_at
      end,
      closed_at = case when next_status = 'closed' then changed_at else null end,
      archived_at = case when next_status = 'archived' then changed_at else null end,
      updated_at = changed_at
  where id = target_inquiry.id;

  if prior_status <> next_status then
    insert into public.audit_events (
      actor_person_id, effective_role_key, brokerage_id, action,
      target_type, target_id, source, correlation_id,
      before_summary, after_summary, occurred_at
    ) values (
      actor_person_id, 'agent', target_inquiry.brokerage_id,
      'inquiry.status_changed', 'inquiry', target_inquiry.id,
      'web', gen_random_uuid(),
      jsonb_build_object('status', prior_status),
      jsonb_build_object('status', next_status),
      changed_at
    );
  end if;

  return null;
end;
$$;

revoke all on function app_private.process_inquiry_status_command()
  from public, anon, authenticated;

comment on column public.inquiries.archived_at is
  'Timestamp when the selected agent archived the inquiry from their active inbox.';
comment on table public.inquiry_status_commands is
  'Write-only professional command boundary for starting, closing, reopening, archiving, or restoring an authorized inquiry.';

commit;
