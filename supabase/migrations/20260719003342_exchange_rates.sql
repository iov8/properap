create table public.exchange_rate_snapshots (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'Open Exchange Rates' check (provider = 'Open Exchange Rates'),
  base_currency char(3) not null default 'USD' check (base_currency = 'USD'),
  jmd_per_usd numeric(18,8) not null check (jmd_per_usd > 0),
  cad_per_usd numeric(18,8) not null check (cad_per_usd > 0),
  gbp_per_usd numeric(18,8) not null check (gbp_per_usd > 0),
  provider_updated_at timestamptz not null,
  fetched_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index exchange_rate_snapshots_fetched_at_idx
  on public.exchange_rate_snapshots (fetched_at desc);

alter table public.exchange_rate_snapshots enable row level security;

create policy exchange_rate_snapshots_public_read
  on public.exchange_rate_snapshots for select to anon, authenticated
  using (true);

revoke all on public.exchange_rate_snapshots from anon, authenticated;
grant select on public.exchange_rate_snapshots to anon, authenticated;
grant select, insert, update, delete on public.exchange_rate_snapshots to service_role;

comment on table public.exchange_rate_snapshots is 'Weekly USD-base rates from Open Exchange Rates used only to display estimated JMD listing conversions.';
