import Link from "next/link";
import { redirect } from "next/navigation";
import { AccountHeader } from "@/app/components/account-header";
import { getActiveMembershipContext } from "@/lib/auth/session";
import { deriveWorkspaceAccess } from "@/lib/auth/workspace-access";
import { createAdminClient } from "@/lib/supabase/admin";
import type { Metadata } from "next";

export const metadata: Metadata = { title: "Analytics", description: "Agent and brokerage performance intelligence.", robots: { index: false, follow: false, noarchive: true, nosnippet: true } };
export const dynamic = "force-dynamic";

const agentSections = [["dashboard","Dashboard"],["listings","Listings"],["audience","Audience"],["inquiries","Inquiries"],["sharing","Sharing"],["website","Website"],["demand","Search demand"],["reports","Monthly reports"]] as const;
const brokerSections = [["dashboard","Dashboard"],["listings","Listings"],["team","Team"],["audience","Audience"],["leads","Lead performance"],["sharing","Sharing"],["website","Website"],["approvals","Approval performance"],["reports","Monthly reports"]] as const;
const ranges = [["7","7 days"],["30","30 days"],["90","90 days"],["365","12 months"]] as const;
type EventRow = { event_name:string; listing_id:string|null; visitor_hash:string; country_code:string|null; source_channel:string; source_surface:string; occurred_at:string };
type ListingRow = { listing_id:string; title:string; assigned_agent_person_id:string|null; assigned_agent_name:string; published_at:string|null };

function href(tab:string, section:string, range:string) { return `/workspace/analytics?tab=${tab}&section=${section}&range=${range}`; }
function percent(value:number, total:number) { return total ? `${Math.round(value / total * 100)}%` : "0%"; }
function bars(rows:Array<{label:string;value:number}>) { const max = Math.max(1, ...rows.map((row) => row.value)); return <div className="analytics-bars">{rows.length ? rows.map((row) => <div className="analytics-bar" key={row.label}><div><strong>{row.label}</strong><span>{row.value.toLocaleString()}</span></div><i><b style={{ width: `${Math.max(3, row.value / max * 100)}%` }} /></i></div>) : <Empty />}</div>; }
function Empty() { return <div className="analytics-empty"><strong>Data will appear here.</strong><p>ProperAP starts measuring this area as visitors interact with your website and listings.</p></div>; }
function Metrics({ items }:{ items:Array<[string,string|number,string]> }) { return <div className="analytics-metrics">{items.map(([label,value,note]) => <article key={label}><span>{label}</span><strong>{value}</strong><p>{note}</p></article>)}</div>; }

export default async function AnalyticsPage({ searchParams }:{ searchParams:Promise<{tab?:string;section?:string;range?:string}> }) {
  const query = await searchParams; const context = await getActiveMembershipContext("/workspace/analytics");
  const access = deriveWorkspaceAccess({ hasMembership:Boolean(context.membership), roles:context.roles, permissions:context.permissions, platformRoles:context.platformRoles });
  const canAgent = access.isAgent; const canBroker = access.canReviewListings || access.canManageAgents || access.canManageBrokerage;
  if (!canAgent && !canBroker) redirect("/access-denied?reason=analytics");
  const tab = query.tab === "broker" && canBroker ? "broker" : canAgent ? "agent" : "broker";
  const sections = tab === "agent" ? agentSections : brokerSections; const section = sections.some(([key]) => key === query.section) ? query.section! : "dashboard";
  // The report boundary must reflect request time, not a build-time constant.
  // eslint-disable-next-line react-hooks/purity
  const range = ranges.some(([key]) => key === query.range) ? query.range! : "30"; const start = new Date(Date.now() - Number(range) * 86_400_000).toISOString();
  const brokerageId = context.membership?.brokerage_id ?? null; const admin = createAdminClient();
  let listingQuery = admin.from("public_listing_snapshots").select("listing_id,title,assigned_agent_person_id,assigned_agent_name,published_at");
  listingQuery = tab === "agent" ? listingQuery.eq("assigned_agent_person_id", context.person.id) : listingQuery.eq("brokerage_id", brokerageId!);
  let eventQuery = admin.from("analytics_events").select("event_name,listing_id,visitor_hash,country_code,source_channel,source_surface,occurred_at").gte("occurred_at", start).order("occurred_at", { ascending:false }).limit(10000);
  eventQuery = tab === "agent" ? eventQuery.or(`owner_agent_person_id.eq.${context.person.id},displaying_agent_person_id.eq.${context.person.id}`) : eventQuery.eq("owner_brokerage_id", brokerageId!);
  let inquiryQuery = admin.from("inquiries").select("id,status,listing_id,created_at,selected_agent_person_id,listing_owner_agent_person_id,displaying_agent_person_id,source_surface").gte("created_at", start);
  inquiryQuery = tab === "agent" ? inquiryQuery.eq("selected_agent_person_id", context.person.id) : inquiryQuery.eq("brokerage_id", brokerageId!);
  const [{ data:listings }, { data:events }, { data:inquiries }] = await Promise.all([listingQuery, eventQuery, inquiryQuery]);
  const listingRows = (listings ?? []) as ListingRow[]; const listingIds = listingRows.map((listing) => listing.listing_id);
  const { data:shares } = tab === "agent"
    ? await admin.from("listing_shares").select("id,listing_id,owner_agent_person_id,displaying_agent_person_id,status,granted_at").or(`owner_agent_person_id.eq.${context.person.id},displaying_agent_person_id.eq.${context.person.id}`).gte("granted_at", start)
    : listingIds.length
      ? await admin.from("listing_shares").select("id,listing_id,owner_agent_person_id,displaying_agent_person_id,status,granted_at").in("listing_id", listingIds).gte("granted_at", start)
      : { data: [] };
  const eventRows = (events ?? []) as EventRow[]; const inquiryRows = inquiries ?? []; const shareRows = shares ?? [];
  const views = eventRows.filter((event) => event.event_name === "listing_viewed"); const unique = new Set(views.map((event) => event.visitor_hash)).size;
  const siteViews = eventRows.filter((event) => event.event_name === (tab === "agent" ? "agent_website_viewed" : "brokerage_website_viewed")).length;
  const countryMap = new Map<string,number>(); for (const event of views) countryMap.set(event.country_code ?? "Unknown", (countryMap.get(event.country_code ?? "Unknown") ?? 0) + 1);
  const sourceMap = new Map<string,number>(); for (const event of eventRows) sourceMap.set(event.source_channel, (sourceMap.get(event.source_channel) ?? 0) + 1);
  const perListing = listingRows.map((listing) => ({ ...listing, views:views.filter((event) => event.listing_id === listing.listing_id).length, visitors:new Set(views.filter((event) => event.listing_id === listing.listing_id).map((event) => event.visitor_hash)).size, inquiries:inquiryRows.filter((row) => row.listing_id === listing.listing_id).length })).sort((a,b) => b.views - a.views);
  const byAgent = new Map<string,{listings:number;views:number;inquiries:number}>(); for (const listing of perListing) { const key = listing.assigned_agent_name || "Unassigned"; const current = byAgent.get(key) ?? {listings:0,views:0,inquiries:0}; current.listings++; current.views += listing.views; current.inquiries += listing.inquiries; byAgent.set(key,current); }
  const countries = [...countryMap].map(([label,value]) => ({label,value})).sort((a,b) => b.value-a.value); const sources = [...sourceMap].map(([label,value]) => ({label:label.replaceAll("_"," "),value})).sort((a,b) => b.value-a.value);
  const pageTitle = tab === "agent" ? "Agent analytics" : "Broker analytics";
  const renderSection = () => {
    if (section === "dashboard") return <><Metrics items={[["Listing views",views.length,"Across the selected period"],["Unique visitors",unique,"Anonymous first-party visitors"],["Inquiries",inquiryRows.length,percent(inquiryRows.length, Math.max(views.length,1))+" view-to-inquiry rate"],["Website visits",siteViews,"Visits to your public website"]]} /><div className="analytics-two-column"><section><span>Top listings</span><h2>What attracts attention</h2>{bars(perListing.slice(0,6).map((row) => ({label:row.title,value:row.views})))}</section><section><span>Audience</span><h2>Where visitors are located</h2>{bars(countries.slice(0,6))}</section></div></>;
    if (section === "listings") return <section className="analytics-panel"><span>Listing performance</span><h2>Views and inquiries by property</h2>{perListing.length ? <div className="analytics-table-wrap"><table><thead><tr><th>Listing</th><th>Views</th><th>Visitors</th><th>Inquiries</th><th>Conversion</th></tr></thead><tbody>{perListing.map((row) => <tr key={row.listing_id}><td>{row.title}</td><td>{row.views}</td><td>{row.visitors}</td><td>{row.inquiries}</td><td>{percent(row.inquiries,row.views)}</td></tr>)}</tbody></table></div> : <Empty />}</section>;
    if (section === "audience") return <div className="analytics-two-column"><section><span>Geography</span><h2>Views by country</h2>{bars(countries)}</section><section><span>Discovery</span><h2>Traffic sources</h2>{bars(sources)}</section></div>;
    if (section === "inquiries" || section === "leads") { const statuses = new Map<string,number>(); inquiryRows.forEach((row) => statuses.set(row.status,(statuses.get(row.status)??0)+1)); return <><Metrics items={[["Total inquiries",inquiryRows.length,"No private client messages shown"],["New",statuses.get("new")??0,"Awaiting follow-up"],["In progress",statuses.get("in_progress")??0,"Currently being handled"],["Closed",statuses.get("closed")??0,"Completed conversations"]]} /><section className="analytics-panel"><span>Pipeline</span><h2>Inquiry status</h2>{bars([...statuses].map(([label,value])=>({label:label.replaceAll("_"," "),value})))}</section></>; }
    if (section === "sharing") return <><Metrics items={[["Active sharing records",shareRows.filter((row)=>row.status==="active").length,"Display permissions currently active"],["Shared listing views",eventRows.filter((e)=>e.source_surface==="shared_agent_site"&&e.event_name==="listing_viewed").length,"Views from another agent website"],["Shared inquiries",inquiryRows.filter((row)=>row.source_surface==="shared_agent_site").length,"Inquiries attributed to shared display"]]} /><section className="analytics-panel"><span>Attribution</span><h2>Shared reach</h2><p>ProperAP attributes views and inquiries to both the listing owner and the displaying agent without changing listing ownership.</p></section></>;
    if (section === "website") return <><Metrics items={[["Website visits",siteViews,"Public website visits"],["Property opens",eventRows.filter((e)=>e.event_name==="listing_card_opened").length,"Cards opened from your presence"],["Inquiries",inquiryRows.length,"Client interest received"]]} /><section className="analytics-panel"><span>Acquisition</span><h2>How people found you</h2>{bars(sources)}</section></>;
    if (section === "team") return <section className="analytics-panel"><span>Brokerage team</span><h2>Performance by representative</h2>{byAgent.size ? <div className="analytics-table-wrap"><table><thead><tr><th>Agent</th><th>Listings</th><th>Views</th><th>Inquiries</th></tr></thead><tbody>{[...byAgent].map(([name,data])=><tr key={name}><td>{name}</td><td>{data.listings}</td><td>{data.views}</td><td>{data.inquiries}</td></tr>)}</tbody></table></div>:<Empty />}</section>;
    if (section === "approvals") return <section className="analytics-panel"><span>Listing governance</span><h2>Approval performance</h2><p>Approval turnaround and correction trends will build from every future submission decision. Existing listing totals remain available now.</p><Metrics items={[["Published inventory",listingRows.length,"Current brokerage portfolio"],["Agents represented",byAgent.size,"Agents with published inventory"]]} /></section>;
    if (section === "demand") return <section className="analytics-panel"><span>Market intent</span><h2>Search demand</h2><p>Search demand will populate as visitors use ProperAP search filters. Only aggregate criteria are retained.</p>{bars(eventRows.filter((e)=>e.event_name==="search_performed").reduce<Array<{label:string;value:number}>>((rows)=>rows.length?rows:[{label:"Recorded searches",value:eventRows.filter((e)=>e.event_name==="search_performed").length}],[]))}</section>;
    return <section className="analytics-panel"><span>Monthly summary</span><h2>A concise report, ready every month.</h2><p>Your report will summarize listing reach, audience, inquiries, sharing, and website growth. Email delivery will begin after a complete reporting month is available.</p><div className="report-preview"><strong>{pageTitle}</strong><span>Period overview</span><b>{views.length} views · {unique} visitors · {inquiryRows.length} inquiries</b></div></section>;
  };

  return <main className="account-page"><AccountHeader displayName={context.person.display_name} hasWorkspace canManageAgents={access.canManageAgents} canManageListings={access.canReviewListings || access.isAgent} canManageInquiries={access.canManageInquiries} canShareListings={access.canShareListings} />
    <section className="account-hero compact"><span className="eyebrow"><i /> Performance intelligence</span><h1>Analytics</h1><p>Understand your reach, audience, and property performance.</p></section>
    <section className="analytics-shell"><div className="website-role-tabs" role="tablist" aria-label="Analytics view">{canAgent?<Link className={tab==="agent"?"active":""} href={href("agent","dashboard",range)}>Agent</Link>:null}{canBroker?<Link className={tab==="broker"?"active":""} href={href("broker","dashboard",range)}>Broker</Link>:null}</div>
      <div className="analytics-toolbar"><div><span>Viewing</span><h2>{pageTitle}</h2></div><nav aria-label="Analytics date range">{ranges.map(([key,label])=><Link key={key} className={range===key?"active":""} href={href(tab,section,key)}>{label}</Link>)}</nav></div>
      <div className="analytics-layout"><aside className="account-section-nav"><strong>{tab === "agent" ? "My performance" : "Brokerage performance"}</strong><nav>{sections.map(([key,label])=><Link key={key} className={section===key?"active":""} href={href(tab,key,range)}>{label}</Link>)}</nav></aside><div className="analytics-content">{renderSection()}</div></div>
    </section></main>;
}
