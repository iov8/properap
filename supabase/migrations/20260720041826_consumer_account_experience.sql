begin;

create table public.consumer_saved_listings (
  person_id uuid not null references public.people(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (person_id, listing_id)
);
create index consumer_saved_listings_person_saved_idx on public.consumer_saved_listings (person_id, saved_at desc);
create index consumer_saved_listings_listing_idx on public.consumer_saved_listings (listing_id);
alter table public.consumer_saved_listings enable row level security;
create policy consumer_saved_listings_owner_read on public.consumer_saved_listings for select to authenticated using (person_id = app_private.current_person_id());
create policy consumer_saved_listings_owner_insert on public.consumer_saved_listings for insert to authenticated with check (person_id = app_private.current_person_id());
create policy consumer_saved_listings_owner_delete on public.consumer_saved_listings for delete to authenticated using (person_id = app_private.current_person_id());
grant select, insert, delete on public.consumer_saved_listings to authenticated;

create table public.consumer_messages (
  id uuid primary key default gen_random_uuid(),
  recipient_person_id uuid not null references public.people(id) on delete cascade,
  sender_person_id uuid references public.people(id) on delete set null,
  sender_label text not null default 'ProperAP' check (char_length(sender_label) between 1 and 120),
  subject text not null check (char_length(subject) between 1 and 160),
  body_safe text not null check (char_length(body_safe) between 1 and 4000),
  read_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
create index consumer_messages_recipient_visible_idx on public.consumer_messages (recipient_person_id, created_at desc) where deleted_at is null;
alter table public.consumer_messages enable row level security;
create policy consumer_messages_recipient_read on public.consumer_messages for select to authenticated using (recipient_person_id = app_private.current_person_id());
create policy consumer_messages_recipient_update on public.consumer_messages for update to authenticated using (recipient_person_id = app_private.current_person_id()) with check (recipient_person_id = app_private.current_person_id());
grant select, update on public.consumer_messages to authenticated;

alter table public.notifications drop constraint if exists notifications_event_type_check;
alter table public.notifications add constraint notifications_event_type_check check (event_type in (
  'listing.draft_created', 'listing.submitted', 'listing.approved', 'listing.changes_requested', 'listing.rejected',
  'listing.saved_listing_updated', 'inquiry.received', 'share.received', 'share.removed', 'share.revoked',
  'agent.application_submitted', 'membership.suspended', 'membership.reactivated', 'membership.removed', 'message.received'
));
alter table public.notifications drop constraint if exists notifications_target_type_check;
alter table public.notifications add constraint notifications_target_type_check check (target_type in ('listing', 'inquiry', 'share', 'agent_application', 'brokerage_membership', 'message'));

create function app_private.notify_saved_listing_update()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  source_event_id uuid;
  listing_title text;
begin
  if new.lifecycle_state not in ('active', 'under_offer')
    or (old.lifecycle_state in ('active', 'under_offer') and new.current_approved_version_id is not distinct from old.current_approved_version_id) then
    return new;
  end if;
  select title into listing_title from public.listing_versions where id = new.current_approved_version_id;
  insert into public.audit_events (actor_person_id, brokerage_id, action, target_type, target_id, source, correlation_id, after_summary)
  values (null, new.brokerage_id, 'listing.saved_listing_updated', 'listing', new.id, 'system', gen_random_uuid(), jsonb_build_object('title', coalesce(listing_title, 'Property listing')))
  returning event_id into source_event_id;
  insert into public.notifications (source_event_id, person_id, brokerage_id, event_type, title, body_safe, target_type, target_id)
  select source_event_id, saved.person_id, new.brokerage_id, 'listing.saved_listing_updated', 'A saved listing was updated', coalesce(listing_title, 'A property listing') || ' has new approved information.', 'listing', new.id
  from public.consumer_saved_listings saved where saved.listing_id = new.id;
  return new;
end;
$$;
create trigger notify_saved_listing_update after update of lifecycle_state, current_approved_version_id on public.listings for each row execute function app_private.notify_saved_listing_update();

create function app_private.notify_consumer_message_received()
returns trigger language plpgsql security definer set search_path = '' as $$
declare source_event_id uuid;
begin
  insert into public.audit_events (actor_person_id, action, target_type, target_id, source, correlation_id, after_summary)
  values (new.sender_person_id, 'message.received', 'message', new.id, 'system', gen_random_uuid(), jsonb_build_object('sender_label', new.sender_label)) returning event_id into source_event_id;
  insert into public.notifications (source_event_id, person_id, event_type, title, body_safe, target_type, target_id)
  values (source_event_id, new.recipient_person_id, 'message.received', new.subject, 'New message from ' || new.sender_label, 'message', new.id);
  return new;
end;
$$;
create trigger notify_consumer_message_received after insert on public.consumer_messages for each row execute function app_private.notify_consumer_message_received();
revoke all on function app_private.notify_saved_listing_update() from public;
revoke all on function app_private.notify_consumer_message_received() from public;

commit;
