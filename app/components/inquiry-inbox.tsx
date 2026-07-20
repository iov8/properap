"use client";

import { useCallback, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { updateInquiryStatusAction } from "@/app/actions/inquiries";
import { useLiveMailbox } from "@/app/components/use-live-mailbox";

export type AgentInquiry = {
  id: string;
  listingId: string;
  listingTitle: string;
  listingLocation: string;
  requesterName: string;
  requesterEmail: string;
  requesterPhone: string | null;
  contactPreference: string;
  message: string;
  status: "new" | "in_progress" | "closed" | "archived";
  createdAt: string;
};

type InquiryStatus = AgentInquiry["status"];
type InquiryFilter = "inbox" | InquiryStatus;
const PAGE_SIZE = 10;
const STATUS_LABELS: Record<InquiryStatus, string> = {
  new: "New inquiry",
  in_progress: "In progress",
  closed: "Closed",
  archived: "Archived",
};

function formatInquiryTime(value: string) {
  return new Intl.DateTimeFormat("en-JM", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "America/Jamaica",
  }).format(new Date(value));
}

export function InquiryInbox({ inquiries }: { inquiries: AgentInquiry[] }) {
  const router = useRouter();
  const [filter, setFilter] = useState<InquiryFilter>("inbox");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const refreshInbox = useCallback(() => router.refresh(), [router]);
  useLiveMailbox("inquiries", refreshInbox);
  const filtered = useMemo(() => {
    const query = search.trim().toLocaleLowerCase();
    return inquiries.filter((inquiry) => {
      const inFolder = filter === "inbox"
        ? (query ? true : inquiry.status !== "archived")
        : inquiry.status === filter;
      const searchable = [inquiry.requesterName, inquiry.requesterEmail, inquiry.listingTitle, inquiry.listingLocation, inquiry.message].join(" ").toLocaleLowerCase();
      return inFolder && (!query || searchable.includes(query));
    });
  }, [filter, inquiries, search]);
  const folders: Array<{ key: InquiryFilter; label: string; count: number }> = [
    { key: "inbox", label: "Inbox", count: inquiries.filter((inquiry) => inquiry.status !== "archived").length },
    { key: "new", label: "New inquiry", count: inquiries.filter((inquiry) => inquiry.status === "new").length },
    { key: "in_progress", label: "In progress", count: inquiries.filter((inquiry) => inquiry.status === "in_progress").length },
    { key: "closed", label: "Closed", count: inquiries.filter((inquiry) => inquiry.status === "closed").length },
    { key: "archived", label: "Archived", count: inquiries.filter((inquiry) => inquiry.status === "archived").length },
  ];
  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, pageCount);
  const visibleInquiries = filtered.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);
  const firstVisible = filtered.length ? ((currentPage - 1) * PAGE_SIZE) + 1 : 0;
  const lastVisible = Math.min(currentPage * PAGE_SIZE, filtered.length);

  return <section className="notification-inbox inquiry-inbox">
    <aside className="notification-folders" aria-label="Inquiry folders">
      <strong>Mailboxes</strong>
      {folders.map((folder) => <button className={filter === folder.key ? "active" : ""} key={folder.key} onClick={() => { setFilter(folder.key); setPage(1); }} type="button"><span>{folder.label}</span><b>{folder.count}</b></button>)}
    </aside>
    <div className="notification-mailbox">
      <div className="notification-mailbox-toolbar">
        <div><span>{folders.find((folder) => folder.key === filter)?.label}</span><strong>{filtered.length ? `${firstVisible}–${lastVisible} of ${filtered.length}` : "0"} message{filtered.length === 1 ? "" : "s"}</strong></div>
        {filter !== "inbox" || search.trim() ? <button className="text-button notification-clear-filter" onClick={() => { setFilter("inbox"); setSearch(""); setPage(1); }} type="button">Clear filters</button> : null}
      </div>
      <label className="notification-search"><span>Search inquiries</span><input value={search} onChange={(event) => { setSearch(event.target.value); setPage(1); }} placeholder="Search buyer, property, message, or archived inquiry" type="search" /></label>
      {visibleInquiries.length ? <div className="notification-list inquiry-mail-list">
        {visibleInquiries.map((inquiry) => <article className={inquiry.status === "new" ? "unread" : ""} key={inquiry.id}>
          <div className="notification-avatar" aria-hidden="true">{inquiry.requesterName.slice(0, 1).toUpperCase()}</div>
          <div className="notification-message">
            <div className="notification-message-heading"><span>{inquiry.requesterName} · {inquiry.requesterEmail}</span><time>{formatInquiryTime(inquiry.createdAt)}</time></div>
            <span className={`inquiry-status-badge status-${inquiry.status}`}>{STATUS_LABELS[inquiry.status]}</span>
            <h2>{inquiry.listingTitle}</h2>
            <p>{inquiry.message}</p>
            <div className="inquiry-mail-details"><span>{inquiry.listingLocation}</span><span>{inquiry.requesterPhone ?? "No phone provided"}</span><span>Reply by {inquiry.contactPreference.replaceAll("_", " ")}</span></div>
          </div>
          <div className="notification-actions inquiry-mail-actions">
            <Link className="outline-dark-button" href={`/properties/${inquiry.listingId}`} target="_blank">Open property</Link>
            {inquiry.status === "new" ? <form action={updateInquiryStatusAction} data-prompt-title="Start following up?" data-prompt-message="This inquiry will move to your In progress folder." data-prompt-confirm="Start follow-up"><input name="inquiryId" type="hidden" value={inquiry.id} /><button className="solid-button" name="operation" value="claim" type="submit">Start follow-up</button></form> : null}
            {inquiry.status === "in_progress" ? <form action={updateInquiryStatusAction} data-prompt-title="Close this inquiry?" data-prompt-message="The message will remain in your private Closed folder." data-prompt-confirm="Close inquiry"><input name="inquiryId" type="hidden" value={inquiry.id} /><button className="solid-button" name="operation" value="close" type="submit">Close inquiry</button></form> : null}
            {inquiry.status === "closed" ? <form action={updateInquiryStatusAction} data-prompt-title="Reopen this inquiry?" data-prompt-message="The message will return to your In progress folder." data-prompt-confirm="Reopen inquiry"><input name="inquiryId" type="hidden" value={inquiry.id} /><button className="outline-dark-button" name="operation" value="reopen" type="submit">Reopen inquiry</button></form> : null}
            {inquiry.status !== "archived" ? <form action={updateInquiryStatusAction} data-prompt-title="Archive this inquiry?" data-prompt-message="The message will leave your Inbox and remain available in Archived and search results." data-prompt-confirm="Archive inquiry"><input name="inquiryId" type="hidden" value={inquiry.id} /><button className="text-button inquiry-archive-button" name="operation" value="archive" type="submit">Archive</button></form> : null}
            {inquiry.status === "archived" ? <form action={updateInquiryStatusAction} data-prompt-title="Restore this inquiry?" data-prompt-message="The message will return to your In progress folder." data-prompt-confirm="Restore inquiry"><input name="inquiryId" type="hidden" value={inquiry.id} /><button className="outline-dark-button" name="operation" value="restore" type="submit">Restore to inbox</button></form> : null}
          </div>
        </article>)}
        {pageCount > 1 ? <nav aria-label="Inquiry pages" className="notification-pagination"><button disabled={currentPage === 1} onClick={() => setPage((value) => Math.max(1, value - 1))} type="button">Previous</button><span>Page {currentPage} of {pageCount}</span><button disabled={currentPage === pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))} type="button">Next</button></nav> : null}
      </div> : <div className="listing-empty"><span>Inbox</span><h2>No matching inquiries.</h2><p>New buyer messages sent to you will appear here.</p></div>}
    </div>
  </section>;
}
