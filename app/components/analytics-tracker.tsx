"use client";

import { useEffect } from "react";

export type AnalyticsEventName = "listing_viewed" | "listing_card_opened" | "listing_saved" | "listing_unsaved" | "listing_shared" | "shared_link_opened" | "contact_clicked" | "inquiry_submitted" | "agent_website_viewed" | "brokerage_website_viewed" | "testimonial_viewed" | "search_performed" | "map_listing_opened";

export function trackAnalyticsEvent(input: { eventName: AnalyticsEventName; listingId?: string; siteId?: string; inquiryId?: string; metadata?: Record<string, string | number | boolean> }) {
  let referrerHost: string | undefined;
  try { referrerHost = document.referrer ? new URL(document.referrer).hostname : undefined; } catch { referrerHost = undefined; }
  void fetch("/api/analytics/events", { method: "POST", credentials: "same-origin", keepalive: true, headers: { "content-type": "application/json" }, body: JSON.stringify({ ...input, referrerHost, eventId: crypto.randomUUID() }) });
}

export function AnalyticsTracker(props: Parameters<typeof trackAnalyticsEvent>[0]) {
  const { eventName, listingId, siteId, inquiryId } = props;
  useEffect(() => { trackAnalyticsEvent({ eventName, listingId, siteId, inquiryId }); }, [eventName, listingId, siteId, inquiryId]);
  return null;
}
