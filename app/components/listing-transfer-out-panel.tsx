"use client";

import { useMemo, useState } from "react";
import { initiateListingTransferOutAction } from "@/app/actions/listings";

export type IndependentAgentRecipient = {
  personId: string;
  firstName: string | null;
  lastName: string | null;
  displayName: string;
  email: string;
};

export function ListingTransferOutPanel({
  listingId,
  recipients,
}: {
  listingId: string;
  recipients: IndependentAgentRecipient[];
}) {
  const [query, setQuery] = useState("");
  const [recipientId, setRecipientId] = useState("");
  const matchingRecipients = useMemo(() => {
    const needle = query.trim().toLocaleLowerCase();
    if (!needle) return recipients;
    return recipients.filter((recipient) => [recipient.firstName, recipient.lastName, recipient.displayName, recipient.email]
      .filter(Boolean).join(" ").toLocaleLowerCase().includes(needle));
  }, [query, recipients]);
  const selectedRecipient = recipients.find((recipient) => recipient.personId === recipientId) ?? null;

  return (
    <section className="listing-transfer-out-panel">
      <div>
        <span>Broker-only ownership handoff</span>
        <h2>Transfer out to an independent agent</h2>
        <p>Search by first and last name, confirm the intended independent agent, and send the request. The listing is removed from public display until they accept or decline.</p>
      </div>
      {recipients.length ? <form action={initiateListingTransferOutAction} data-prompt-title="Transfer this listing out?" data-prompt-message="The listing will be unpublished immediately. The independent agent must accept before it becomes their private draft." data-prompt-confirm="Send transfer request">
        <input type="hidden" name="listingId" value={listingId} />
        <input type="hidden" name="recipientPersonId" value={recipientId} />
        <label>
          <span>Find an active independent agent</span>
          <input value={query} onChange={(event) => { setQuery(event.target.value); setRecipientId(""); }} placeholder="Start with first or last name" />
        </label>
        <div className="transfer-recipient-results" aria-live="polite">
          {matchingRecipients.slice(0, 8).map((recipient) => (
            <button className={recipient.personId === recipientId ? "selected" : ""} key={recipient.personId} onClick={() => setRecipientId(recipient.personId)} type="button">
              <strong>{recipient.firstName || recipient.displayName} {recipient.lastName || ""}</strong>
              <span>{recipient.email}</span>
            </button>
          ))}
          {!matchingRecipients.length ? <p>No eligible independent agent matches that name.</p> : null}
        </div>
        {selectedRecipient ? <p className="transfer-recipient-confirmation">Selected: <strong>{selectedRecipient.displayName}</strong> · {selectedRecipient.email}</p> : null}
        <button className="solid-button" disabled={!selectedRecipient} type="submit">Send transfer request</button>
      </form> : <p className="transfer-empty-state">There are no active independent agents available to receive a transfer yet. ProperAP must activate an independent-agent profile before it can be selected.</p>}
    </section>
  );
}
