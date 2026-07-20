import { redirect } from "next/navigation";
import { AccountHeader } from "@/app/components/account-header";
import { StaffNav } from "@/app/components/staff-nav";
import { getActiveMembershipContext } from "@/lib/auth/session";
import { deriveWorkspaceAccess } from "@/lib/auth/workspace-access";
import { createAdminClient } from "@/lib/supabase/admin";
import { progressProfessionalRegistrationAction } from "@/app/actions/staff";
import { StatusMessage } from "@/app/components/status-message";

export const dynamic = "force-dynamic";
const date = (value: string) => new Intl.DateTimeFormat("en-JM", { dateStyle: "medium" }).format(new Date(value));

const nextStep = (status: string, type: string) => {
  if (status === "submitted" && type === "agent") return null;
  if (status === "submitted" || status === "brokerage_approved") return ["process", "Process"] as const;
  if (status === "processing") return ["payment", "Record payment"] as const;
  if (status === "payment_pending") return ["approve", "Approve"] as const;
  if (status === "approved") return ["activate", "Activate"] as const;
  return null;
};

export default async function StaffRegistrationsPage({ searchParams }: { searchParams: Promise<{ notice?: string; error?: string }> }) {
  const query = await searchParams;
  const context = await getActiveMembershipContext("/staff/registrations");
  const access = deriveWorkspaceAccess({ hasMembership: Boolean(context.membership), roles: context.roles, permissions: context.permissions, platformRoles: context.platformRoles });
  if (!access.isOperations && !access.isAdmin) redirect("/access-denied?reason=platform-operations");
  const { data: requests } = await createAdminClient().from("professional_registration_requests").select("id,request_type,status,origin,contact_phone,contact_address,created_at,people(first_name,last_name,primary_email),brokerages(display_name)").order("created_at", { ascending: false }).limit(25);
  return <main className="account-page"><AccountHeader displayName={context.person.display_name} isOperations={access.isOperations} isAdmin={access.isAdmin} />
    <section className="account-hero compact"><span className="eyebrow"><i /> ProperAP operations</span><h1>Members</h1><p>Process professional registrations from review through payment, approval, and activation.</p></section>
    <div className="account-settings-layout staff-layout"><StaffNav active="registrations" /><div className="account-main"><StatusMessage notice={query.notice} error={query.error} /><section className="account-card"><div className="card-heading"><span>Professional registration queue</span><h2>Process member access</h2></div><p>Agents first require brokerage approval. Then ProperAP records contact review, payment, approval, and activation.</p><div className="staff-table-scroll"><table className="staff-table"><thead><tr><th>Name</th><th>Requested role</th><th>Brokerage</th><th>Contact</th><th>Submitted</th><th>Status</th><th>Next step</th></tr></thead><tbody>{requests?.map((request) => { const person = request.people as unknown as { first_name: string; last_name: string; primary_email: string | null } | null; const brokerage = request.brokerages as unknown as { display_name: string } | null; const step = nextStep(request.status, request.request_type); return <tr key={request.id}><td><strong>{person ? `${person.first_name} ${person.last_name}` : "Account unavailable"}</strong><small>{person?.primary_email ?? "—"}</small></td><td>{request.request_type === "agent" ? "Agent" : "Broker"}<small>{request.origin === "upgrade" ? "Account upgrade" : "New registration"}</small></td><td>{brokerage?.display_name ?? "New brokerage"}</td><td>{request.contact_phone}<small>{request.contact_address}</small></td><td>{date(request.created_at)}</td><td><span className={`record-status status-${request.status}`}>{request.status.replaceAll("_", " ")}</span></td><td>{step ? <form action={progressProfessionalRegistrationAction} className="staff-registration-action"><input type="hidden" name="requestId" value={request.id} /><input type="hidden" name="operation" value={step[0]} /><input name="notes" aria-label={`${step[1]} notes for ${person?.first_name ?? "member"}`} placeholder={step[0] === "process" ? "Review and contact notes" : step[0] === "payment" ? "Payment reference" : "Optional note"} /><button className="outline-dark-button" type="submit">{step[1]}</button></form> : <small>{request.status === "submitted" && request.request_type === "agent" ? "Awaiting brokerage approval" : request.status === "active" ? "Active member" : "No action available"}</small>}</td></tr>; })}</tbody></table></div></section></div></div>
  </main>;
}
