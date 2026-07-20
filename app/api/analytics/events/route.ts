import { createHash, randomUUID } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";
const schema = z.object({ eventName: z.enum(["listing_viewed","listing_card_opened","listing_saved","listing_unsaved","listing_shared","shared_link_opened","contact_clicked","inquiry_submitted","agent_website_viewed","brokerage_website_viewed","testimonial_viewed","search_performed","map_listing_opened"]), eventId: z.string().uuid(), listingId: z.string().uuid().optional(), siteId: z.string().uuid().optional(), inquiryId: z.string().uuid().optional(), metadata: z.record(z.string(), z.union([z.string().max(120), z.number(), z.boolean()])).optional() }).strict();
const hash = (value: string) => createHash("sha256").update(value).digest("hex");
const allowedMetadata = new Set(["queryType", "resultCount", "currency", "action"]);

function validOrigin(request: NextRequest) { const origin = request.headers.get("origin"); if (!origin) return false; try { const host = new URL(origin).hostname.toLowerCase(); return host === "properap.com" || host.endsWith(".properap.com") || host === "localhost" || host === "127.0.0.1"; } catch { return false; } }
function deviceType(ua: string) { if (/ipad|tablet/i.test(ua)) return "tablet"; if (/mobile|android|iphone/i.test(ua)) return "mobile"; return ua ? "desktop" : "other"; }
function referral(request: NextRequest) { const raw = request.headers.get("referer"); if (!raw) return { host: null, channel: "direct" }; try { const host = new URL(raw).hostname.toLowerCase().replace(/^www\./, ""); if (host === "properap.com" || host.endsWith(".properap.com")) return { host, channel: "properap" }; if (/google|bing|yahoo|duckduckgo/.test(host)) return { host, channel: "search" }; if (/facebook|instagram|linkedin|tiktok|youtube|snapchat/.test(host)) return { host, channel: "social" }; return { host: /^[a-z0-9.-]+$/.test(host) ? host.slice(0, 253) : null, channel: "referral" }; } catch { return { host: null, channel: "unknown" }; } }

export async function POST(request: NextRequest) {
  if (!validOrigin(request)) return NextResponse.json({ error: "Invalid origin." }, { status: 403 });
  const parsed = schema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Invalid analytics event." }, { status: 400 });
  const admin = createAdminClient(); const visitorId = request.cookies.get("properap_visitor")?.value ?? randomUUID(); const sessionId = request.cookies.get("properap_session")?.value ?? randomUUID(); const visitorHash = hash(visitorId);
  const { count } = await admin.from("analytics_events").select("id", { head: true, count: "exact" }).eq("visitor_hash", visitorHash).gte("occurred_at", new Date(Date.now() - 60_000).toISOString());
  if ((count ?? 0) >= 60) return new NextResponse(null, { status: 429 });
  let listing: { id:string; brokerage_id:string; assigned_agent_person_id:string|null } | null = null; let site: { id:string; site_type:string; owner_person_id:string|null; owner_brokerage_id:string|null } | null = null;
  if (parsed.data.listingId) { const result = await admin.from("public_listing_snapshots").select("listing_id,brokerage_id,assigned_agent_person_id").eq("listing_id", parsed.data.listingId).maybeSingle(); if (!result.data) return NextResponse.json({ error: "Listing unavailable." }, { status: 404 }); listing = { id: result.data.listing_id, brokerage_id: result.data.brokerage_id, assigned_agent_person_id: result.data.assigned_agent_person_id }; }
  if (parsed.data.siteId) { const result = await admin.from("professional_sites").select("id,site_type,owner_person_id,owner_brokerage_id").eq("id", parsed.data.siteId).eq("status", "active").maybeSingle(); if (!result.data) return NextResponse.json({ error: "Website unavailable." }, { status: 404 }); site = result.data; }
  if (["listing_viewed","listing_card_opened","listing_saved","listing_unsaved","listing_shared","map_listing_opened"].includes(parsed.data.eventName) && !listing) return NextResponse.json({ error: "Listing required." }, { status: 400 });
  if (["agent_website_viewed","brokerage_website_viewed"].includes(parsed.data.eventName) && !site) return NextResponse.json({ error: "Website required." }, { status: 400 });
  let displayingAgent = site?.site_type === "agent" ? site.owner_person_id : null; let sourceSurface = site?.site_type === "agent" ? "agent_site" : site?.site_type === "brokerage" ? "brokerage_site" : "marketplace"; let shareId: string | null = null;
  if (listing && displayingAgent && displayingAgent !== listing.assigned_agent_person_id) { const { data: share } = await admin.from("listing_shares").select("id").eq("listing_id", listing.id).eq("displaying_agent_person_id", displayingAgent).eq("status", "active").maybeSingle(); if (!share) displayingAgent = null; else { shareId = share.id; sourceSurface = "shared_agent_site"; } }
  const metadata = Object.fromEntries(Object.entries(parsed.data.metadata ?? {}).filter(([key]) => allowedMetadata.has(key))); const country = request.headers.get("x-vercel-ip-country")?.toUpperCase(); const ref = referral(request);
  const { error } = await admin.from("analytics_events").upsert({ event_key: hash(`${sessionId}:${parsed.data.eventId}`), event_name: parsed.data.eventName, listing_id: listing?.id ?? null, site_id: site?.id ?? null, inquiry_id: parsed.data.inquiryId ?? null, listing_share_id: shareId, owner_agent_person_id: listing?.assigned_agent_person_id ?? site?.owner_person_id ?? null, displaying_agent_person_id: displayingAgent, owner_brokerage_id: listing?.brokerage_id ?? site?.owner_brokerage_id ?? null, visitor_hash: visitorHash, session_hash: hash(sessionId), country_code: country && /^[A-Z]{2}$/.test(country) ? country : null, region_code: request.headers.get("x-vercel-ip-country-region")?.slice(0, 80) || null, device_type: deviceType(request.headers.get("user-agent") ?? ""), source_channel: ref.channel, source_surface: sourceSurface, referrer_host: ref.host, metadata }, { onConflict: "event_key", ignoreDuplicates: true });
  if (error) return NextResponse.json({ error: "Event not recorded." }, { status: 500 });
  const response = new NextResponse(null, { status: 202, headers: { "cache-control": "no-store" } }); const secure = process.env.NODE_ENV === "production";
  if (!request.cookies.has("properap_visitor")) response.cookies.set("properap_visitor", visitorId, { httpOnly: true, sameSite: "lax", secure, maxAge: 31_536_000, path: "/", domain: secure ? ".properap.com" : undefined });
  if (!request.cookies.has("properap_session")) response.cookies.set("properap_session", sessionId, { httpOnly: true, sameSite: "lax", secure, maxAge: 1_800, path: "/", domain: secure ? ".properap.com" : undefined }); return response;
}
