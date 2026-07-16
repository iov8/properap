# Database development

SteadFast database changes are defined as ordered SQL migrations under
supabase/migrations and are reviewed in Git before they reach any hosted
Supabase project.

## Local verification

Docker must be running. Then use:

1. npm install
2. npm run supabase:start
3. npm run db:verify
4. npm run supabase:stop

The local database is disposable and uses only synthetic seed data. It is not a
local production deployment and must never contain client or production data.
Supabase's local services use development-only default credentials and may bind
to the local network, so start them only for testing and stop them immediately
afterward.

## Creating a migration

Run npx supabase migration new followed by a short descriptive name. Edit the
generated file, reset the local database from zero, run pgTAP tests, and review
the resulting SQL before committing.

Every table in an exposed schema must have Row Level Security enabled. API
access also requires explicit grants; RLS alone does not expose a table.
Authorization must use database-owned membership and capability records, never
user-editable authentication metadata.

## Applying migrations

Preview, staging and production use separate Supabase projects and credentials.
Migrations are promoted in order after CI passes. Do not make undocumented
schema changes in the Supabase dashboard.

The production project is not linked or modified by the automated test
workflow. Hosted deployment credentials will be added only when a controlled
staging promotion workflow is approved.
