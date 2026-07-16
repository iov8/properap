begin;

-- Internal objects live outside the exposed Data API schemas. Explicitly
-- revoke access so future objects are private by default.
create schema if not exists app_private;

revoke all on schema app_private from public;
revoke all on schema app_private from anon;
revoke all on schema app_private from authenticated;

comment on schema app_private is
  'SteadFast internal database objects. Not exposed through the Data API.';

commit;
