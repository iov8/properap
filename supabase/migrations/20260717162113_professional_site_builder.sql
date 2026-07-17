create table public.site_assets (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.professional_sites(id) on delete cascade,
  placement text not null check (placement in ('profile_photo','brokerage_logo','testimonial_photo')),
  bucket_id text not null default 'professional-site-assets' check (bucket_id='professional-site-assets'),
  object_path text not null unique check (object_path ~ '^[a-z0-9-]+/[a-z0-9-]+/[a-z0-9-]+\.webp$'),
  original_filename text not null check (char_length(original_filename) between 1 and 180),
  mime_type text not null default 'image/webp' check (mime_type='image/webp'),
  byte_size integer not null check (byte_size > 0 and byte_size <= 5242880),
  width integer not null check (width between 128 and 2400),
  height integer not null check (height between 128 and 2400),
  status text not null default 'ready' check (status in ('ready','removed')),
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  check ((status='removed') = (removed_at is not null))
);
create unique index site_assets_one_active_placement_idx on public.site_assets(site_id, placement) where status='ready' and placement in ('profile_photo','brokerage_logo');
create index site_assets_site_ready_idx on public.site_assets(site_id, status, placement);

create table public.site_testimonials (
  id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.professional_sites(id) on delete cascade,
  author_name text not null check (char_length(btrim(author_name)) between 1 and 120),
  author_context text check (author_context is null or char_length(btrim(author_context)) <= 180),
  quote text not null check (char_length(btrim(quote)) between 10 and 1200),
  asset_id uuid references public.site_assets(id) on delete set null,
  position smallint not null check (position between 1 and 10),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(site_id, position)
);
create index site_testimonials_public_idx on public.site_testimonials(site_id, is_active, position);

create table public.brokerage_subscription_records (
  id uuid primary key default gen_random_uuid(),
  brokerage_id uuid not null references public.brokerages(id),
  plan_key text not null check (plan_key in ('agent','brokerage_20','brokerage_growth')),
  status text not null check (status in ('paid','pending','cancelled','expired')),
  billing_period text not null check (billing_period in ('monthly','annual')),
  amount_cents integer not null check (amount_cents >= 0),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  paid_at timestamptz,
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  provider text not null default 'manual_demo' check (char_length(provider) <= 60),
  provider_reference text check (provider_reference is null or char_length(provider_reference) <= 160),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default now()
);
create index brokerage_subscription_records_brokerage_idx on public.brokerage_subscription_records(brokerage_id, status, ends_at desc);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('professional-site-assets', 'professional-site-assets', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

alter table public.professional_sites
  add column layout jsonb not null default '{"sectionOrder":["hero","about","search","listings","testimonials","contact"]}'::jsonb check (jsonb_typeof(layout)='object'),
  add column content jsonb not null default '{}'::jsonb check (jsonb_typeof(content)='object');

alter table public.site_assets enable row level security;
alter table public.site_testimonials enable row level security;
alter table public.brokerage_subscription_records enable row level security;

create policy site_assets_public_ready_read on public.site_assets for select to anon, authenticated
  using (status='ready' and exists (select 1 from public.professional_sites site where site.id=site_assets.site_id and site.status='active'));
create policy site_testimonials_public_active_read on public.site_testimonials for select to anon, authenticated
  using (is_active and exists (select 1 from public.professional_sites site where site.id=site_testimonials.site_id and site.status='active'));

revoke all on public.site_assets, public.site_testimonials, public.brokerage_subscription_records from anon, authenticated;
grant select on public.site_assets, public.site_testimonials to anon, authenticated;
grant select,insert,update,delete on public.site_assets, public.site_testimonials, public.brokerage_subscription_records to service_role;

create trigger site_testimonials_touch_updated_at before update on public.site_testimonials for each row execute function app_private.touch_updated_at();
comment on table public.site_assets is 'Private WebP assets for professional profiles and sites. Public display is mediated by a SteadFast route; storage paths are never exposed.';
comment on table public.site_testimonials is 'Public, site-owner-controlled testimonials limited to ten ordered records per professional site.';
