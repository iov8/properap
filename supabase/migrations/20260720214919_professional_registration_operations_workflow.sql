-- ProperAP Operations moves professional registrations through a visible
-- customer-service workflow. Brokerage approval for agent applicants remains
-- a separate prerequisite before Operations processing begins.
alter table public.professional_registration_requests
  drop constraint professional_registration_requests_status_check;

update public.professional_registration_requests
set status = case status
  when 'properap_approved' then 'approved'
  when 'activated' then 'active'
  else status
end
where status in ('properap_approved', 'activated');

alter table public.professional_registration_requests
  add constraint professional_registration_requests_status_check
  check (status in ('submitted', 'brokerage_approved', 'processing', 'payment_pending', 'approved', 'active', 'denied', 'withdrawn')),
  add column if not exists processed_by_person_id uuid references public.people(id),
  add column if not exists processed_at timestamptz,
  add column if not exists process_notes text check (process_notes is null or char_length(process_notes) <= 2000),
  add column if not exists payment_recorded_by_person_id uuid references public.people(id),
  add column if not exists payment_recorded_at timestamptz,
  add column if not exists payment_reference text check (payment_reference is null or char_length(payment_reference) <= 160);

drop index if exists public.professional_registration_one_open_idx;
create unique index professional_registration_one_open_idx on public.professional_registration_requests(person_id)
  where status in ('submitted', 'brokerage_approved', 'processing', 'payment_pending', 'approved');
