-- Notify the broker and delegated listing reviewers as soon as an agent starts
-- a new brokerage listing. The draft remains private and is not an approval
-- request until the agent explicitly submits it.
alter table public.notifications
  drop constraint if exists notifications_event_type_check;
alter table public.notifications
  add constraint notifications_event_type_check check (
    event_type in (
      'listing.draft_created', 'listing.submitted', 'listing.approved',
      'listing.changes_requested', 'listing.rejected', 'inquiry.received',
      'share.received', 'share.removed', 'share.revoked'
    )
  );

create function app_private.create_listing_draft_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  notification_id uuid;
begin
  if new.action <> 'listing.draft_created'
    or new.target_type <> 'listing'
    or new.target_id is null
    or new.brokerage_id is null then
    return new;
  end if;

  for recipient in
    select distinct membership.person_id
    from public.brokerage_memberships as membership
    where membership.brokerage_id = new.brokerage_id
      and membership.status = 'active'
      and membership.person_id <> new.actor_person_id
      and (
        exists (
          select 1
          from public.membership_roles as role
          where role.membership_id = membership.id
            and role.role_key = 'broker'
            and role.starts_at <= now()
            and (role.ends_at is null or role.ends_at > now())
        )
        or (
          not exists (
            select 1
            from public.membership_permissions as permission
            where permission.membership_id = membership.id
              and permission.permission_key = 'listing.review'
              and permission.effect = 'deny'
              and permission.starts_at <= now()
              and (permission.ends_at is null or permission.ends_at > now())
          )
          and (
            exists (
              select 1
              from public.membership_permissions as permission
              where permission.membership_id = membership.id
                and permission.permission_key = 'listing.review'
                and permission.effect = 'allow'
                and permission.starts_at <= now()
                and (permission.ends_at is null or permission.ends_at > now())
            )
            or exists (
              select 1
              from public.membership_roles as role
              join public.role_permissions as role_permission
                on role_permission.role_key = role.role_key
              where role.membership_id = membership.id
                and role_permission.permission_key = 'listing.review'
                and role.starts_at <= now()
                and (role.ends_at is null or role.ends_at > now())
            )
          )
        )
      )
  loop
    insert into public.notifications (
      source_event_id, person_id, brokerage_id, event_type, title,
      body_safe, target_type, target_id, created_at
    ) values (
      new.event_id, recipient.person_id, new.brokerage_id,
      'listing.draft_created', 'New listing draft created',
      'An agent created a private listing draft in your brokerage.',
      'listing', new.target_id, new.occurred_at
    )
    on conflict (person_id, source_event_id, event_type) do nothing
    returning id into notification_id;

    if notification_id is not null then
      insert into app_private.outbox_events (
        topic, notification_id, aggregate_type, aggregate_id, payload,
        available_at
      ) values (
        'notification.email.requested', notification_id, 'listing',
        new.target_id,
        jsonb_build_object(
          'notification_id', notification_id,
          'person_id', recipient.person_id,
          'event_type', 'listing.draft_created'
        ),
        new.occurred_at
      );
    end if;
    notification_id := null;
  end loop;

  return new;
end;
$$;

create trigger create_listing_draft_notifications
  after insert on public.audit_events
  for each row execute function app_private.create_listing_draft_notifications();

revoke all on function app_private.create_listing_draft_notifications()
  from public, anon, authenticated;
