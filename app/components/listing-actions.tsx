"use client";

import { useEffect, useId, useState } from "react";
import { trackAnalyticsEvent } from "@/app/components/analytics-tracker";

const savedListingsKey = "properap-saved-listing-ids";

function readSavedListings() {
  try {
    const stored = window.localStorage.getItem(savedListingsKey);
    const parsed = stored ? JSON.parse(stored) : [];
    return new Set(Array.isArray(parsed) ? parsed.filter((value): value is string => typeof value === "string") : []);
  } catch {
    return new Set<string>();
  }
}

function HeartIcon({ filled }: { filled: boolean }) {
  return <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M20.8 4.9a5.5 5.5 0 0 0-7.8 0L12 6l-1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.3a5.5 5.5 0 0 0 0-7.8Z" fill={filled ? "currentColor" : "none"} stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" /></svg>;
}

function ShareIcon() {
  return <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M7.5 12.1 16.7 7M7.5 12.1l9.2 4.9M18.5 8.3a2.8 2.8 0 1 0 0-5.6 2.8 2.8 0 0 0 0 5.6ZM5.5 14.9a2.8 2.8 0 1 0 0-5.6 2.8 2.8 0 0 0 0 5.6Zm13 6.4a2.8 2.8 0 1 0 0-5.6 2.8 2.8 0 0 0 0 5.6Z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

export function ListingActions({ listingId, title, siteId, className = "" }: { listingId: string; title: string; siteId?: string; className?: string }) {
  const [saved, setSaved] = useState(false);
  const [message, setMessage] = useState("");
  const messageId = useId();

  useEffect(() => { setSaved(readSavedListings().has(listingId)); }, [listingId]);

  function toggleSaved() {
    const listings = readSavedListings();
    const nextSaved = !listings.has(listingId);
    if (nextSaved) listings.add(listingId); else listings.delete(listingId);
    try { window.localStorage.setItem(savedListingsKey, JSON.stringify([...listings])); } catch { /* Saving remains an optional browser convenience. */ }
    setSaved(nextSaved);
    setMessage(nextSaved ? "Listing saved" : "Listing removed from saved listings");
    trackAnalyticsEvent({ eventName: nextSaved ? "listing_saved" : "listing_unsaved", listingId, siteId });
  }

  async function shareListing() {
    const url = `${window.location.origin}/properties/${listingId}${siteId ? `?site=${encodeURIComponent(siteId)}` : ""}`;
    const supportsNativeShare = "share" in navigator;
    try {
      if (supportsNativeShare) await navigator.share({ title, text: `Take a look at ${title} on ProperAP.`, url });
      else await navigator.clipboard.writeText(url);
      setMessage(supportsNativeShare ? "Share ready" : "Listing link copied");
      trackAnalyticsEvent({ eventName: "listing_shared", listingId, siteId });
    } catch (error) {
      if ((error as DOMException).name !== "AbortError") setMessage("Unable to share this listing right now");
    }
  }

  return <div className={`listing-actions ${className}`.trim()} role="group" aria-label={`Actions for ${title}`}>
    <button type="button" className={saved ? "is-saved" : ""} onClick={toggleSaved} aria-pressed={saved} aria-label={saved ? `Remove ${title} from saved listings` : `Save ${title}`} title={saved ? "Saved" : "Save listing"} aria-describedby={message ? messageId : undefined}><HeartIcon filled={saved} /></button>
    <button type="button" onClick={() => void shareListing()} aria-label={`Share ${title}`} title="Share listing" aria-describedby={message ? messageId : undefined}><ShareIcon /></button>
    <span id={messageId} className="listing-actions-status" aria-live="polite">{message}</span>
  </div>;
}
