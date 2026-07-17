create table public.person_profile_assets (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people(id) on delete cascade,
  bucket_id text not null default 'professional-site-assets' check (bucket_id='professional-site-assets'),
  object_path text not null unique check (object_path ~ '^people/[a-z0-9-]+/[a-z0-9-]+\.webp$'),
  original_filename text not null check (char_length(original_filename) between 1 and 180),
  byte_size integer not null check (byte_size > 0 and byte_size <= 5242880),
  width integer not null check (width between 128 and 2400),
  height integer not null check (height between 128 and 2400),
  status text not null default 'ready' check (status in ('ready','removed')),
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  check ((status='removed') = (removed_at is not null))
);
create unique index person_profile_assets_one_active_idx on public.person_profile_assets(person_id) where status='ready';
alter table public.person_profile_assets enable row level security;
create policy person_profile_assets_read_self on public.person_profile_assets for select to authenticated using (person_id = app_private.current_person_id());
revoke all on public.person_profile_assets from anon, authenticated;
grant select,insert,update,delete on public.person_profile_assets to service_role;
grant select on public.person_profile_assets to authenticated;
comment on table public.person_profile_assets is 'Private personal profile photographs for signed-in account surfaces; never publicly exposed.';
