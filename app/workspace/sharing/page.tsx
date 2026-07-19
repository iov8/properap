import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { AccountHeader } from "@/app/components/account-header";
import { ListingSharingTables } from "@/app/components/listing-sharing-tables";
import { StatusMessage } from "@/app/components/status-message";
import { getActiveMembershipContext } from "@/lib/auth/session";
import { deriveWorkspaceAccess } from "@/lib/auth/workspace-access";

export const metadata: Metadata = {
  title: "Listing sharing",
  description: "Manage display-only listing shares between ProperAP agents.",
  robots: { index: false, follow: false, noarchive: true },
};
export const dynamic = "force-dynamic";

type SharingView = "mine" | "shared";

function sharingHref(view: SharingView) {
  return view === "mine" ? "/workspace/sharing" : "/workspace/sharing?view=shared";
}

function sharingPageHref(view: SharingView, page: number) {
  const parameters = new URLSearchParams();
  if (view === "shared") parameters.set("view", "shared");
  if (page > 1) parameters.set("page", String(page));
  const query = parameters.toString();
  return query ? `/workspace/sharing?${query}` : "/workspace/sharing";
}

export default async function SharingPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; notice?: string; view?: string; page?: string }>;
}) {
  const query = await searchParams;
  const selectedView: SharingView = query.view === "shared" ? "shared" : "mine";
  const context = await getActiveMembershipContext("/workspace/sharing");
  const access = deriveWorkspaceAccess({
    hasMembership: Boolean(context.membership),
    roles: context.roles,
    permissions: context.permissions,
    platformRoles: context.platformRoles,
  });
  if (!access.canShareListings) redirect("/access-denied?reason=listing-sharing");

  const [{ data: listings }, { data: sites }, { data: shares }] = await Promise.all([
    context.supabase
      .from("public_listing_snapshots")
      .select("listing_id,title,published_at")
      .eq("assigned_agent_person_id", context.person.id),
    context.supabase
      .from("professional_sites")
      .select("owner_person_id,display_name,slug")
      .eq("site_type", "agent")
      .eq("status", "active")
      .neq("owner_person_id", context.person.id),
    context.supabase
      .from("listing_shares")
      .select("id,listing_id,owner_agent_person_id,displaying_agent_person_id,status,granted_at")
      .eq("status", "active")
      .or(`owner_agent_person_id.eq.${context.person.id},displaying_agent_person_id.eq.${context.person.id}`),
  ]);

  const incomingListingIds = [...new Set((shares ?? []).filter((share) => share.displaying_agent_person_id === context.person.id).map((share) => share.listing_id))];
  const { data: incomingListings } = incomingListingIds.length
    ? await context.supabase.from("public_listing_snapshots").select("listing_id,title,published_at").in("listing_id", incomingListingIds)
    : { data: [] };
  const siteNames = new Map((sites ?? []).map((site) => [site.owner_person_id, site.display_name]));
  const listingNames = new Map((incomingListings ?? []).map((listing) => [listing.listing_id, listing]));
  const formatDate = (value: string | null | undefined) => value ? new Intl.DateTimeFormat("en-JM", { dateStyle: "medium", timeZone: "America/Jamaica" }).format(new Date(value)) : "Not available";
  const ownedListings = (listings ?? []).map((listing) => ({
    id: listing.listing_id,
    title: listing.title,
    listedDate: formatDate(listing.published_at),
    shares: (shares ?? []).filter((share) => share.owner_agent_person_id === context.person.id && share.listing_id === listing.listing_id).map((share) => ({ id: share.id, agentName: siteNames.get(share.displaying_agent_person_id) ?? "Agent" })),
  }));
  const incomingShares = (shares ?? []).filter((share) => share.displaying_agent_person_id === context.person.id).map((share) => {
    const listing = listingNames.get(share.listing_id);
    return { id: share.id, listingId: share.listing_id, title: listing?.title ?? "Shared listing", listedDate: formatDate(listing?.published_at ?? share.granted_at), ownerName: siteNames.get(share.owner_agent_person_id) ?? "Listing owner" };
  });
  const pageSize = 5;
  const activeRecords = selectedView === "mine" ? ownedListings : incomingShares;
  const totalPages = Math.max(1, Math.ceil(activeRecords.length / pageSize));
  const requestedPage = Number.parseInt(query.page ?? "1", 10);
  const currentPage = Math.min(Math.max(Number.isFinite(requestedPage) ? requestedPage : 1, 1), totalPages);
  const pageStart = (currentPage - 1) * pageSize;
  const visibleOwnedListings = selectedView === "mine" ? ownedListings.slice(pageStart, pageStart + pageSize) : [];
  const visibleIncomingShares = selectedView === "shared" ? incomingShares.slice(pageStart, pageStart + pageSize) : [];

  return <main className="account-page">
    <AccountHeader displayName={context.person.display_name} hasWorkspace canManageAgents={access.canManageAgents} canManageListings canManageInquiries={access.canManageInquiries} canShareListings />
    <section className="account-hero compact"><span className="eyebrow"><i /> Display advertising</span><h1>Listing sharing.</h1><p>Share approved listings without changing ownership or editing rights.</p></section>
    <section className="sharing-shell">
      <StatusMessage error={query.error} notice={query.notice} />
      <div className="sharing-layout">
        <aside className="listing-status-nav sharing-nav" aria-label="Listing sharing sections">
          <strong>Sharing</strong>
          <nav>
            <Link href={sharingHref("mine")} className={selectedView === "mine" ? "active" : undefined} aria-current={selectedView === "mine" ? "page" : undefined}><span>My listing</span><small>{ownedListings.length}</small></Link>
            <Link href={sharingHref("shared")} className={selectedView === "shared" ? "active" : undefined} aria-current={selectedView === "shared" ? "page" : undefined}><span>Shared with me</span><small>{incomingShares.length}</small></Link>
          </nav>
        </aside>

        <div className="sharing-content">
          <section className="sharing-records" aria-labelledby="sharing-table-title">
            <header><div><span>Display permissions</span><h2 id="sharing-table-title">{selectedView === "mine" ? "My listing" : "Shared with me"}</h2></div><p>{selectedView === "mine" ? ownedListings.length : incomingShares.length} records</p></header>
            <ListingSharingTables view={selectedView} ownedListings={visibleOwnedListings} incomingShares={visibleIncomingShares} agents={(sites ?? []).map((site) => ({ id: site.owner_person_id!, name: site.display_name }))} />
            {totalPages > 1 ? <nav className="listing-pagination" aria-label={`${selectedView === "mine" ? "My listing" : "Shared with me"} pages`}>
              {currentPage > 1 ? <Link href={sharingPageHref(selectedView, currentPage - 1)}>Previous</Link> : <span>Previous</span>}
              <strong>Page {currentPage} of {totalPages}</strong>
              {currentPage < totalPages ? <Link href={sharingPageHref(selectedView, currentPage + 1)}>Next</Link> : <span>Next</span>}
            </nav> : null}
          </section>
        </div>
      </div>
    </section>
  </main>;
}
