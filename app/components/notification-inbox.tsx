"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  markAllNotificationsReadAction,
  markNotificationReadAction,
} from "@/app/actions/notifications";

export type InboxNotification = {
  id: string;
  eventType: string;
  title: string;
  body: string;
  targetType: string;
  targetId: string;
  readAt: string | null;
  createdAt: string;
  actorName: string | null;
  activity: string;
};

type Filter = "all" | "unread" | "listing" | "approval";

function formatNotificationTime(value: string) {
  return new Intl.DateTimeFormat("en-JM", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "America/Jamaica",
  }).format(new Date(value));
}

function isApproval(eventType: string) {
  return eventType === "listing.submitted" || eventType === "listing.approved" || eventType === "listing.changes_requested" || eventType === "listing.rejected";
}

export function NotificationInbox({ notifications }: { notifications: InboxNotification[] }) {
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");
  const unreadCount = notifications.filter((notification) => !notification.readAt).length;
  const filtered = useMemo(() => {
    const query = search.trim().toLocaleLowerCase();
    return notifications.filter((notification) => {
      const inFilter = filter === "all"
        || (filter === "unread" && !notification.readAt)
        || (filter === "listing" && notification.targetType === "listing")
        || (filter === "approval" && isApproval(notification.eventType));
      const searchable = [notification.title, notification.body, notification.actorName ?? "", notification.activity].join(" ").toLocaleLowerCase();
      return inFilter && (!query || searchable.includes(query));
    });
  }, [filter, notifications, search]);

  const filters: Array<{ key: Filter; label: string; count: number }> = [
    { key: "all", label: "Inbox", count: notifications.length },
    { key: "unread", label: "Unread", count: unreadCount },
    { key: "listing", label: "Listing activity", count: notifications.filter((notification) => notification.targetType === "listing").length },
    { key: "approval", label: "Approvals", count: notifications.filter((notification) => isApproval(notification.eventType)).length },
  ];

  return (
    <section className="notification-inbox">
      <aside className="notification-folders" aria-label="Notification folders">
        <strong>Mailboxes</strong>
        {filters.map((item) => (
          <button key={item.key} type="button" className={filter === item.key ? "active" : ""} onClick={() => setFilter(item.key)}>
            <span>{item.label}</span><b>{item.count}</b>
          </button>
        ))}
      </aside>
      <div className="notification-mailbox">
        <div className="notification-mailbox-toolbar">
          <div>
            <span>{filter === "all" ? "Inbox" : filters.find((item) => item.key === filter)?.label}</span>
            <strong>{filtered.length} message{filtered.length === 1 ? "" : "s"}</strong>
          </div>
          {unreadCount > 0 ? <form action={markAllNotificationsReadAction}><button className="outline-dark-button" type="submit">Mark all as read</button></form> : null}
        </div>
        <label className="notification-search">
          <span>Search notifications</span>
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search title or user" type="search" />
        </label>
        {filtered.length ? <div className="notification-list">
          {filtered.map((notification) => (
            <article className={notification.readAt ? "" : "unread"} key={notification.id}>
              <div className="notification-avatar" aria-hidden="true">{(notification.actorName ?? "S").slice(0, 1).toUpperCase()}</div>
              <div className="notification-message">
                <div className="notification-message-heading"><span>{notification.activity}</span><time>{formatNotificationTime(notification.createdAt)}</time></div>
                <h2>{notification.title}</h2>
                <p>{notification.body}</p>
              </div>
              <div className="notification-actions">
                {notification.targetType === "listing" ? <Link className="solid-button" href={`/workspace/listings/${notification.targetId}`}>Open listing</Link> : null}
                {notification.targetType === "share" ? <Link className="solid-button" href="/workspace/sharing">Open sharing</Link> : null}
                {notification.targetType === "inquiry" ? <Link className="solid-button" href="/workspace/inquiries">Open inquiry</Link> : null}
                {!notification.readAt ? <form action={markNotificationReadAction}><input name="notificationId" type="hidden" value={notification.id} /><button className="text-button" type="submit">Mark read</button></form> : <span className="notification-read-state">Read</span>}
              </div>
            </article>
          ))}
        </div> : <div className="listing-empty"><span>Inbox</span><h2>No matching notifications.</h2><p>Try a different search or folder.</p></div>}
      </div>
    </section>
  );
}
