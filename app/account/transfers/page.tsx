import type { Metadata } from "next";
import { AccountHeader } from "@/app/components/account-header";
import { StatusMessage } from "@/app/components/status-message";
import { respondToListingTransferOutAction } from "@/app/actions/listings";
import { requireAccount } from "@/lib/auth/session";
import { createAdminClient } from "@/lib/supabase/admin";

export const metadata: Metadata = {
  title: "Listing transfers",
  description: "Review private listing ownership transfer requests.",
  robots: { index: false, follow: false },
};
export const dynamic = "force-dynamic";

export default async function ListingTransfersPage({ searchParams }: { searchParams: Promise<{ notice?: string; error?: string }> }) {
  const query = await searchParams;
  const account = await requireAccount("/account/transfers");
  const admin = createAdminClient();
  const { data: transfers } = await account.supabase
    .from("listing_transfer_out_requests")
    .select("id,listing_id,source_brokerage_id,status,response_reason,created_at,responded_at,initiated_by_person_id")
    .order("created_at", { ascending: false });
  const listingIds = (transfers ?? []).map((transfer) => transfer.listing_id);
  const initiatorIds = (transfers ?? []).map((transfer) => transfer.initiated_by_person_id);
  const [{ data: listings }, { data: brokers }, { data: brokerages }] = await Promise.all([
    listingIds.length ? admin.from("listing_versions").select("listing_id,title").in("listing_id", listingIds).order("version_number", { ascending: false }) : { data: [] as Array<{ listing_id: string; title: string }> },
    initiatorIds.length ? admin.from("people").select("id,display_name").in("id", initiatorIds) : { data: [] as Array<{ id: string; display_name: string }> },
    (transfers ?? []).length ? admin.from("brokerages").select("id,display_name").in("id", (transfers ?? []).map((transfer) => transfer.source_brokerage_id)) : { data: [] as Array<{ id: string; display_name: string }> },
  ]);
  const titles = new Map<string, string>();
  for (const listing of listings ?? []) if (!titles.has(listing.listing_id)) titles.set(listing.listing_id, listing.title);
  const brokerNames = new Map((brokers ?? []).map((person) => [person.id, person.display_name]));
  const brokerageNames = new Map((brokerages ?? []).map((brokerage) => [brokerage.id, brokerage.display_name]));

  return <main className="account-page">
    <AccountHeader displayName={account.person.display_name} isConsumer />
    <section className="account-hero compact"><span className="eyebrow"><i /> Independent agent workspace</span><h1>Listing transfers</h1><p>Review brokerage listings offered to your independent agent account.</p></section>
    <div className="account-main transfer-account-main">
      <StatusMessage notice={query.notice} error={query.error} />
      {(transfers ?? []).length ? <div className="transfer-inbox-list">{(transfers ?? []).map((transfer) => <article key={transfer.id}>
        <div><span>{transfer.status.replaceAll("_", " ")}</span><h2>{titles.get(transfer.listing_id) ?? "Property listing"}</h2><p>From <strong>{brokerageNames.get(transfer.source_brokerage_id) ?? "Brokerage"}</strong> · initiated by {brokerNames.get(transfer.initiated_by_person_id) ?? "Broker"}</p><small>{new Date(transfer.created_at).toLocaleString("en-JM", { dateStyle: "medium", timeStyle: "short" })}</small></div>
        {transfer.status === "pending" ? <div className="transfer-response-actions">
          <form action={respondToListingTransferOutAction} data-prompt-title="Accept this listing transfer?" data-prompt-message="The listing becomes your private independent-agent draft. It will not be public until you review and publish it." data-prompt-confirm="Accept transfer">
            <input name="transferId" type="hidden" value={transfer.id} /><input name="decision" type="hidden" value="accept" />
            <button className="solid-button" type="submit">Accept transfer</button>
          </form>
          <form action={respondToListingTransferOutAction} data-prompt-title="Decline this listing transfer?" data-prompt-message="The brokerage retains the listing, and it remains unpublished." data-prompt-confirm="Decline transfer">
            <input name="transferId" type="hidden" value={transfer.id} /><input name="decision" type="hidden" value="decline" />
            <label><span>Optional reason</span><input name="reason" maxLength={1000} placeholder="Optional note for the brokerage" /></label>
            <button className="outline-dark-button" type="submit">Decline</button>
          </form>
        </div> : <p className="transfer-response-summary">{transfer.status === "accepted" ? "You accepted this transfer. The listing is now your private draft." : transfer.status === "declined" ? "You declined this transfer." : `This transfer is ${transfer.status}.`}</p>}
      </article>)}</div> : <section className="empty-state-card"><h2>No listing transfers</h2><p>When a brokerage offers you a listing, you will see it here and receive a notification.</p></section>}
    </div>
  </main>;
}
