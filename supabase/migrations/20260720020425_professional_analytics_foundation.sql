-- Privacy-safe first-party analytics. Public clients never receive direct
-- table access; the server validates public targets and derives ownership.
create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique check (event_key ~ '^[0-9a-f]{64}$'),
  event_name text not null check (
    event_name in (
      'listing_viewed',
      'listing_card_opened',
      'listing_saved',
      'listing_unsaved',
      'listing_shared',
      'shared_link_opened',
      'contact_clicked',
      'inquiry_submitted',
      'agent_website_viewed',
      'brokerage_website_viewed',
      'testimonial_viewed',
      'search_performed',
      'map_listing_opened'
    )
  ),
  listing_id uuid references public.listings(id) on delete set null,
  site_id uuid references public.professional_sites(id) on delete set null,
  inquiry_id uuid references public.inquiries(id) on delete set null,
  listing_share_id uuid references public.listing_shares(id) on delete set null,
  owner_agent_person_id uuid references public.people(id) on delete set null,
  displaying_agent_person_id uuid references public.people(id) on delete set null,
  owner_brokerage_id uuid references public.brokerages(id) on delete set null,
  visitor_hash text not null check (visitor_hash ~ '^[0-9a-f]{64}$'),
  session_hash text not null check (session_hash ~ '^[0-9a-f]{64}$'),
  authenticated_person_id uuid references public.people(id) on delete set null,
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  region_code text check (region_code is null or char_length(region_code) <= 80),
  device_type text not null default 'other'
    check (device_type in ('desktop','mobile','tablet','other')),
  source_channel text not null default 'unknown'
    check (source_channel in ('direct','properap','search','social','email','shared','referral','unknown')),
  source_surface text not null default 'marketplace'
    check (source_surface in ('marketplace','agent_site','brokerage_site','shared_agent_site')),
  referrer_host text check (
    referrer_host is null
    or (
      char_length(referrer_host) <= 253
      and referrer_host ~ '^[a-z0-9.-]+$'
    )
  ),
  metadata jsonb not null default '{}'::jsonb
    check (
      jsonb_typeof(metadata) = 'object'
      and octet_length(metadata::text) <= 4096
    ),
  occurred_at timestamptz not null default clock_timestamp()
);

create index analytics_events_agent_time_idx
  on public.analytics_events (owner_agent_person_id, occurred_at desc)
  where owner_agent_person_id is not null;
create index analytics_events_display_agent_time_idx
  on public.analytics_events (displaying_agent_person_id, occurred_at desc)
  where displaying_agent_person_id is not null;
create index analytics_events_brokerage_time_idx
  on public.analytics_events (owner_brokerage_id, occurred_at desc)
  where owner_brokerage_id is not null;
create index analytics_events_listing_time_idx
  on public.analytics_events (listing_id, occurred_at desc)
  where listing_id is not null;
create index analytics_events_site_time_idx
  on public.analytics_events (site_id, occurred_at desc)
  where site_id is not null;
create index analytics_events_country_time_idx
  on public.analytics_events (country_code, occurred_at desc)
  where country_code is not null;
create index analytics_events_name_time_idx
  on public.analytics_events (event_name, occurred_at desc);
create index analytics_events_visitor_rate_idx
  on public.analytics_events (visitor_hash, occurred_at desc);

alter table public.analytics_events enable row level security;

-- Analytics are intentionally server-only. Role checks happen again in the
-- protected analytics page before the server uses its privileged client.
revoke all on table public.analytics_events from public, anon, authenticated;
grant select, insert, update, delete on table public.analytics_events to service_role;

comment on table public.analytics_events is
  'Server-recorded, privacy-safe product analytics. Raw IP addresses, full referrer URLs, inquiry text, and visitor contact details are prohibited.';
comment on column public.analytics_events.visitor_hash is
  'One-way hash of a random first-party visitor identifier; never an IP address or email address.';
comment on column public.analytics_events.metadata is
  'Small allowlisted event details only. It must never contain contact details, free-form messages, raw URLs, or secrets.';
