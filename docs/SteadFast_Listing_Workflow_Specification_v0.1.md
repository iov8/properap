# SteadFast Listing Workflow Specification

**Version:** 0.1 - Planning Draft  
**Prepared:** July 2026  
**Status:** Product and engineering workflow baseline  
**Applies to:** SteadFast MVP for Jamaican brokerages and agents

## 1. Purpose

This document defines the complete MVP workflow for creating, reviewing, approving, publishing, changing, sharing, reassigning, closing, and archiving property listings. It is the authoritative behavior baseline for application screens, APIs, database constraints, notifications, audit events, automated tests, and future external listing feeds.

The brokerage owns every listing created under it. An agent represents the listing. Every publicly displayed listing must have an active assigned agent. Brokers and authorized broker staff control approval; SteadFast operations does not approve listings or decide professional disputes.

## 2. Scope

### Included in the MVP

- Residential sales and long-term rentals.
- Commercial property, land, and developments.
- Draft creation and validation.
- Broker or authorized staff approval.
- Immutable submitted versions and before/after comparison.
- Public, professional-network, and private visibility.
- Under-offer, sold, rented, withdrawn, expired, unassigned, and archived outcomes.
- Agent-to-agent display sharing.
- Agent departure and representative reassignment.
- Brokerage and agent website publication.
- Public search, maps, and inquiries.
- Feed-ready distribution eligibility and delivery history.
- Notifications, flags, and append-only audit records.

### Excluded or deferred

- Vacation and short-term rental workflows.
- Tenant, lease, rent-collection, maintenance, and inspection management.
- Transaction closing, commission, and commission-sharing accounting.
- Automatic legal ownership verification by SteadFast.
- Guaranteed MLS or portal distribution before written authorization.
- Emergency legal or security content restriction until policy approval.

## 3. Governing rules

1. **Brokerage ownership:** the brokerage owns the listing record and approved versions.
2. **Agent representation:** an active assigned agent is required for every public listing.
3. **Broker-controlled approval:** initial publication and every material change require approval by the broker or staff with `listing.review`.
4. **Stable public version:** a proposed change never overwrites the current approved public version before approval.
5. **Immutable submissions:** every submission and decision is retained. Approved, returned, rejected, withdrawn, and superseded versions are not erased.
6. **Authorized self-approval:** a broker or staff member who is also an agent may approve their own submission if they hold `listing.review`; the event is marked as self-approval.
7. **Archive, do not delete:** removal closes or archives a listing. The application never permanently deletes listing, approval, assignment, share, or distribution history.
8. **Sharing is display permission:** sharing requires no broker approval and grants no editing, approval, reassignment, ownership, or private-data access.
9. **Immediate safety unpublish:** if the assigned agent or brokerage becomes ineligible, public and external display stops immediately without waiting for a new approval decision.
10. **SteadFast boundary:** operations may record flags, notify the broker, and monitor response, but cannot suspend an ordinary listing, approve it, or resolve brokerage disputes.
11. **Fail closed:** if eligibility or workflow state is missing, conflicting, or unverifiable, the listing is not published or distributed.
12. **One active material proposal:** the MVP permits one open material-change proposal per listing. This prevents conflicting approvals. A submitter may withdraw it and start again from the current approved version.

## 4. Workflow records

| Record | Purpose | Key ownership rule |
|---|---|---|
| Property | Represents the physical real-world asset and stable location/fact identity. | A property may support multiple historical or contractually valid listings. Possible duplicates are flagged, not automatically merged. |
| Listing | Brokerage-controlled offer to sell or rent a property. Holds lifecycle, assignment, visibility, and current approved-version references. | Owned by one brokerage for its full lifetime; never transfers with a departing agent. |
| Listing version | Immutable snapshot of listing content, facts, price, media order, location display, representative request, visibility, and status request. | Created by a professional; becomes public only after approval and eligibility checks. |
| Review decision | Approve, return with changes requested, or reject a submitted version. | Made only by the broker or staff with `listing.review` inside the listing brokerage. |
| Assignment | Time-bounded relationship between a listing and its representative agent. | Agent must be active in the listing brokerage. Assignment history is retained. |
| Display share | Permission for another eligible agent to advertise an approved listing on that agent's website. | Granted by the assigned owner agent; never changes brokerage ownership or listing content. |
| Publication | Materialized public or professional display derived from an approved version and current eligibility. | Automatically removed when any guard becomes false. |
| Distribution record | Destination-specific eligibility, external ID, validation, delivery, update, error, and removal history. | External identity never replaces SteadFast listing identity. |
| Audit event | Append-only record of security-sensitive or business-significant actions. | No application role may edit or delete it. |

## 5. Two-part state model

SteadFast must not represent all behavior in one status field. A listing has a **lifecycle state**, while each proposed version has a separate **revision state**. The interface may show a derived label such as **Changes pending** without replacing the active lifecycle state.

### 5.1 Listing lifecycle states

| State | Meaning | Public behavior |
|---|---|---|
| Draft | New listing has no approved version. | Never public. |
| Pending initial approval | First submitted version awaits brokerage decision. | Never public. |
| Approved inactive | An approved version exists but publication guards are not yet satisfied or publication is intentionally inactive. | Not public. |
| Active | Approved listing is eligible and marketed according to visibility. | Public or professional when visibility permits. |
| Under offer | Broker-approved status indicating an accepted or active offer while marketing display continues under brokerage policy. | Visible with an Under offer label unless visibility is not public. |
| Withdrawn | Broker-approved removal from active marketing. | Removed from active search, websites, shares, and feeds. |
| Sold | Broker-approved completed sale status. | Removed from active search and active advertising. Historical display is a later policy decision. |
| Rented | Broker-approved completed long-term rental status. | Removed from active search and active advertising. Historical display is a later policy decision. |
| Expired | Listing marketing period ended under the approved expiry rule. | Removed until an extension or republication is approved. |
| Unassigned | No eligible active representative exists. | Immediately removed from all public, shared, and external displays. |
| Archived | Closed record retained for history, reporting, and compliance. | Never public as an active listing. |

### 5.2 Listing-version states

| State | Meaning | Editable? |
|---|---|---|
| Working draft | Agent or authorized brokerage user is preparing a version. | Yes, by permitted creator/assignee users. |
| Submitted | Immutable snapshot awaiting review. | No. It must be withdrawn or returned before revision. |
| Changes requested | Reviewer returned the submission with required corrections. | The returned snapshot stays immutable; a new working revision is created from it. |
| Rejected | Reviewer declined the submission. | No. A new working revision may be started if the listing remains eligible. |
| Approved | Reviewer accepted the exact snapshot. | No. It becomes or replaces the listing's approved version atomically. |
| Withdrawn | Submitter cancelled the pending review before a decision. | No. A new working revision may be created. |
| Superseded | A newer approved version replaced this previously approved version. | No. It remains available in history. |

### 5.3 Derived interface labels

| Label | Derivation |
|---|---|
| Changes pending | Lifecycle is Active or Under offer and a submitted material-change version exists. |
| Corrections requested | Latest proposal is Changes requested and a replacement working draft is available. |
| Awaiting republication | Approved content exists, but lifecycle or eligibility prevents display. |
| Unassigned - action required | Lifecycle is Unassigned and the brokerage must appoint an active representative. |
| Distribution issue | SteadFast publication is valid, but one or more authorized external destinations has a delivery or validation failure. |

## 6. Publication eligibility guard

A listing may appear in public search, maps, agent websites, brokerage websites, shared displays, or external feeds only when every applicable rule passes.

| Guard | Required condition |
|---|---|
| Approved content | `current_approved_version_id` exists and references an approved immutable version. |
| Lifecycle | State is Active or Under offer. |
| Visibility | Public for unauthenticated display; Professional network for eligible authenticated professionals. |
| Brokerage | Brokerage is active and permitted to publish. |
| Representative | Assigned agent is active, approved, and a current member of the owning brokerage. |
| Subscription | Required brokerage and professional entitlements are active or inside an approved grace rule. |
| Property/location | Required location and map fields are valid for the selected display policy. |
| Media/content | Required fields and launch media rules pass validation. |
| Share | Shared agent display additionally requires an active share and an eligible displaying agent. |
| External destination | Written authorization, plan entitlement, destination rules, approved status, and successful destination validation all pass. |

Eligibility is evaluated on initial publication and after every relevant listing, agent, brokerage, subscription, share, configuration, or destination event. If a guard changes from pass to fail, unpublication and destination removal are queued immediately and idempotently.

## 7. New listing workflow

### 7.1 Creation and drafting

1. An active agent starts a listing inside their one active brokerage.
2. The system creates a listing and first working version with private visibility.
3. The agent links an existing property or creates a property candidate.
4. Duplicate detection checks normalized address, coordinates, unit, property facts, and active listing relationships.
5. A possible duplicate creates a broker-visible flag; it does not automatically merge, reject, or publish the record.
6. The agent enters price, currency, purpose, property type, address, coordinates, public description, material facts, media, visibility request, and representation details.
7. Draft autosaves do not create approval events. Significant saves may create safe edit history without exposing sensitive form content in logs.
8. The agent runs or receives validation and corrects blocking errors.

### 7.2 Submission

The system must complete the following atomically:

1. Confirm the submitter is active, belongs to the owning brokerage, and is permitted to submit the listing.
2. Confirm the assigned representative is active in the same brokerage.
3. Validate all required content, media, location, price, visibility, and lifecycle fields at runtime.
4. Confirm no other open material proposal exists.
5. Freeze the exact submitted version as immutable.
6. Move the listing from Draft to Pending initial approval.
7. Create an audit event and review-queue item.
8. Notify the broker and every staff member who is eligible and configured to receive listing-review notifications.

### 7.3 Review

The reviewer sees:

- the submitted public content and media in intended display order;
- submitter and assigned representative;
- property identity and duplicate flags;
- visibility and publication request;
- required validation results;
- proposed values compared with the current approved version, when one exists;
- prior returns, rejections, decisions, comments, and self-approval indicator; and
- any distribution eligibility consequences known at review time.

The reviewer cannot silently alter the submitted snapshot. To change content, the reviewer returns it with required corrections or creates a separately attributable proposal under their own permitted agent/workflow role.

### 7.4 Decision outcomes

| Decision | Required input | Result | Notification |
|---|---|---|---|
| Approve | Confirmation; reason optional unless policy requires it. | Version becomes Approved. Listing becomes Active when all publication guards pass, otherwise Approved inactive. | Submitter, assigned agent, and relevant brokerage reviewers. |
| Changes requested | Reviewer comment describing required correction. | Submitted snapshot becomes Changes requested; listing remains non-public for initial submission. New working version is created from the returned snapshot. | Submitter and assigned agent. |
| Reject | Required reason. | Submitted snapshot becomes Rejected; listing remains non-public. A later proposal requires a new working version. | Submitter and assigned agent. |
| Withdraw | Submitter confirmation and optional reason before reviewer decision. | Submitted snapshot becomes Withdrawn; listing returns to Draft for initial submission. | Reviewers and assigned agent. |

### 7.5 Approval transaction

Approval must be atomic. The system must not expose a partially applied listing.

1. Re-check reviewer permission, brokerage scope, listing state, and submitted-version identity.
2. Re-run validation and publication eligibility because membership or data may have changed during review.
3. Record reviewer, effective role, decision, timestamp, comments, and whether it is self-approval.
4. Mark the exact submitted version Approved.
5. Mark the former approved version Superseded when applicable.
6. Update the listing's current approved-version reference and approved lifecycle values.
7. Recalculate publication, website, share, search, map, and destination outputs.
8. Create audit, notification, and integration events using an idempotent transaction/outbox approach.

If any required database step fails, none of the approval state is committed. Delivery work may retry safely without applying the approval twice.

## 8. Material change workflow

### 8.1 Changes requiring approval

The following are material in the MVP:

- price, currency, sale/rental purpose, and financial display fields;
- public title, description, features, property facts, and development details;
- address, coordinates, parish/area, unit identity, and public location precision;
- media files, captions, ordering, floor plans, and virtual-tour links;
- assigned representative;
- visibility and publication channels;
- property or listing type;
- under-offer, sold, rented, withdrawn, expired, removal, archive, and republication requests;
- external distribution choices where brokerage authorization or plan rules require approval; and
- any field not explicitly classified as non-material.

Non-material actions include personal inquiry handling, internal draft notes, notification preferences, and whether a displaying agent shows an existing share on their own website. Non-material actions must never be used to change public listing content.

### 8.2 Proposal behavior while a listing is active

1. The agent starts a working change version from the current approved version.
2. The current approved version remains active and public.
3. The system shows changed fields and media differences as the proposal is prepared.
4. Submission freezes the proposed version and creates the derived Changes pending label.
5. While submitted, the exact snapshot cannot be edited.
6. Approval atomically replaces the approved version and updates every SteadFast display.
7. Return, rejection, or withdrawal leaves the current public version unchanged.
8. Every displaying agent receives a notification after an approved public change; displays update automatically.
9. Destination adapters receive an idempotent update only after approval and eligibility evaluation.

### 8.3 Concurrency rules

- Only one open material proposal may exist per listing in the MVP.
- A working draft may be edited by permitted users, but optimistic concurrency prevents one browser session from silently overwriting another.
- Submitted snapshots are immutable.
- If the approved version changes before a proposal is submitted, the system requires review of the new baseline and a rebase or restart.
- A reviewer decision must verify the version is still the current submitted proposal.
- Duplicate requests, retries, and webhook callbacks use idempotency keys.

## 9. Lifecycle and status transitions

| From | Requested action | Approval required | Result | Public effect |
|---|---|---|---|---|
| Draft | Submit initial version | Yes | Pending initial approval | None; remains private. |
| Pending initial approval | Approve | Reviewer decision | Active or Approved inactive | Publish only if all guards pass. |
| Pending initial approval | Return or reject | Reviewer decision | Draft/returned work or closed rejected proposal | None. |
| Active | Approve material content change | Reviewer decision | Active with new approved version | Atomic display update. |
| Active | Approve Under offer | Reviewer decision | Under offer | Remains visible with status. |
| Under offer | Approve return to Active | Reviewer decision | Active | Status label removed. |
| Active or Under offer | Approve Sold | Reviewer decision | Sold | Remove from active displays and feeds. |
| Active or Under offer | Approve Rented | Reviewer decision | Rented | Remove from active displays and feeds. |
| Active or Under offer | Approve Withdrawn | Reviewer decision | Withdrawn | Remove from active displays and feeds. |
| Active or Under offer | Reach approved expiry rule | System transition under policy | Expired | Remove from active displays and feeds; notify brokerage. |
| Active or Under offer | Assigned agent becomes ineligible | Immediate system guard | Unassigned | Remove immediately; approval is not delayed for safety. |
| Unassigned | Assign replacement and approve republication | Yes | Active or Approved inactive | Publish only after assignment and guards pass. |
| Withdrawn, Expired, Sold, or Rented | Approve republication when business rules permit | Yes | Active or Approved inactive | New approved version and eligibility required. |
| Closed state | Approve archive | Yes | Archived | Retained privately; never active. |

Sold or rented records are not automatically reusable as a new marketing period. A new contractually valid listing may reference the same property through a new listing record, preserving the historical offer.

## 10. Assignment and agent departure

### 10.1 Planned reassignment

1. A broker or staff member with `listing.reassign` selects an active agent in the same brokerage.
2. If the listing is public, representative change is material and follows approval.
3. The former approved representative remains public until the replacement is approved, unless the former representative becomes ineligible.
4. Approval closes the former assignment, opens the new assignment, updates contacts, re-evaluates shares, and notifies both agents.
5. Assignment history remains visible to authorized brokerage users.

### 10.2 Agent departure or deactivation

The following occurs immediately when the brokerage membership becomes inactive:

1. The former agent loses access to the brokerage's private records.
2. Every listing represented by that agent becomes Unassigned.
3. The listings are removed from public search, maps, the brokerage website, the former agent website, shared agent websites, and external feeds.
4. Active display shares are suspended because the underlying listing is ineligible.
5. The listings remain private brokerage-owned records with complete history.
6. The broker and authorized staff receive an action-required notification.
7. The agent account, personal profile, website configuration, and non-brokerage history remain active.

The broker then assigns an eligible replacement and submits or approves republication. Former-brokerage listings never transfer to the agent's new brokerage.

## 11. Display sharing workflow

### 11.1 Grant

An assigned owner agent may grant an eligible active SteadFast agent permission to display an approved listing. Broker approval is not required.

The system verifies:

- the grantor is the listing's current active assigned agent;
- the listing has an approved version and is eligible for the requested display;
- the recipient is an active eligible agent;
- the share is not a duplicate active grant; and
- plan or display limits permit the share.

The share records listing, owner agent, displaying agent, grant time, status, and source. The recipient is notified and may accept or decline if the product uses an acceptance step. Until that UI decision is finalized, the data model must support offered, active, declined, removed, revoked, suspended, and ended states.

### 11.2 Display behavior

- The displaying agent may show or hide the active share on their own website.
- The listing content always comes from the current approved listing version.
- The page shows the displaying agent and listing-owner agent.
- The visitor chooses the primary contact.
- Both agents receive the inquiry notification; the selected agent is recorded as primary.
- The displaying agent cannot edit the listing or see private brokerage content.

### 11.3 Removal and automatic suspension

| Event | Result | Notification |
|---|---|---|
| Displaying agent removes listing from own site | Share becomes Removed for that display. | Owner agent is notified. |
| Owner agent revokes share | Share becomes Revoked and disappears from recipient site. | Displaying agent is notified. |
| Approved listing changes | Active share remains; all displays update from the new approved version. | Every displaying agent is notified. |
| Listing becomes sold, rented, withdrawn, expired, archived, unassigned, or otherwise unpublished | Share becomes Suspended or Ended and disappears automatically. | Owner and displaying agents are notified as applicable. |
| Displaying agent becomes ineligible | Display is suspended. Listing ownership and original publication are unaffected. | Displaying agent and system monitors are notified. |
| Owner agent changes through approved reassignment | Existing shares are re-evaluated under brokerage policy. | Former owner, new owner, and displaying agents are notified of the result. |

## 12. Visibility workflow

| Visibility | Audience | Approval and behavior |
|---|---|---|
| Private | Assigned agent and authorized brokerage users. | Used for drafts, pending work, internal records, and ineligible approved records. Never searchable publicly. |
| Professional network | Authenticated eligible SteadFast professionals. | Requires approved content, active brokerage, active representative, and professional eligibility. Not visible to consumers. |
| Public | Visitors and registered users. | Requires approved Active/Under offer lifecycle and every public eligibility guard. |

Changing visibility is material and requires approval. Public location data must use the approved location-display rule. Private documents, review comments, duplicate evidence, audit data, internal notes, and unpublished precise fields never appear in public or professional output unless specifically classified for that audience.

## 13. External distribution workflow

SteadFast maintains its own canonical listing and approval workflow. RAJ/MLS, Realtor.com International/Move, and future destinations are adapters, not owners of core state.

1. A listing version is approved inside SteadFast.
2. The distribution engine evaluates brokerage authorization, listing permission, plan entitlement, destination field requirements, lifecycle, visibility, and representative eligibility.
3. An eligibility result is recorded for each destination.
4. Eligible content is mapped to the destination format using the current approved version only.
5. Submission uses a destination idempotency key and retains request reference, safe response summary, external identifier, and timestamp.
6. Delivery success or validation errors are visible to authorized brokerage and operations users.
7. Approved changes create destination updates.
8. Unpublication or terminal states create removal/closure requests.
9. Failed deliveries retry safely without duplicating listings.
10. External responses never bypass SteadFast ownership, approval, or audit rules.

No destination is activated until written authorization and feed requirements are confirmed.

## 14. Flags and disputes

1. A user or internal operator records a flag with category, source, evidence reference, and listing/account target.
2. SteadFast operations reviews only enough information to route the issue and identify system risk.
3. Operations notifies the responsible broker and records delivery.
4. The broker or authorized staff investigates and responds under brokerage responsibility.
5. Operations records response status and follow-up timing.
6. An ordinary flag does not automatically suspend, edit, approve, reject, or transfer the listing.
7. System-generated publication guards still act immediately when objective eligibility fails.
8. Any future emergency legal/security control requires a separately approved policy, restricted permission, reason, confirmation, and immutable audit.

## 15. Notifications

| Event | Required recipients | Minimum message content |
|---|---|---|
| Initial submission | Broker and configured reviewers | Listing reference, submitter, representative, submission time, authorized review link. |
| Changes requested or rejected | Submitter and assigned agent | Decision, reviewer, reason/comment, authorized correction/history link. |
| Approved | Submitter, assigned agent, relevant reviewers | Decision, effective time, publication outcome, self-approval indicator when applicable. |
| Material change approved | Assigned agent and all displaying agents | Changed-field summary safe for recipient, effective time, display outcome. |
| Share granted/accepted/declined | Participating agents | Listing, other agent, share status, time. |
| Share removed or revoked | Participating agents | Listing, actor, result, time. |
| Inquiry submitted | Selected primary agent and secondary listing/display agent | Listing, source site, selected contact, consumer-provided details, delivery reference. |
| Agent deactivated or departed | Broker, authorized staff, affected agent | Membership result, access result, count of unassigned/unpublished listings, action link. |
| Listing unassigned | Broker, authorized staff, former representative | Listing, reason, public removal, reassignment action. |
| Sold/rented/withdrawn/expired | Assigned agent, reviewers, displaying agents | Approved status, effective time, display/feed removal result. |
| Distribution failure | Authorized brokerage integration users and operations | Destination, listing, safe error category, retry state, authorized link. |
| Flag notification | Responsible broker and assigned operations user | Category, evidence reference, response request, due/follow-up status. |

Notifications are in-app and email for the MVP. Each notification records event source, recipient, read state, delivery state, attempt count, and authorized destination. Duplicate delivery is controlled.

## 16. Audit requirements

The following events are append-only and mandatory:

- listing and property candidate creation;
- submission, withdrawal, return, rejection, approval, and self-approval;
- approved-version replacement and lifecycle transition;
- visibility, representative, price, location, media, and status changes;
- assignment start/end and agent departure handling;
- share grant, acceptance, decline, removal, revocation, suspension, and end;
- public publication, unpublication, and republication;
- distribution eligibility, delivery, update, failure, retry, and removal;
- flag creation, broker notification, response, and closure; and
- any privileged support or administrative access to listing workflow data.

Each event records actor, effective role, brokerage context, action, target identifiers, source, request/correlation reference, timestamp, reason/comment when required, and a safe before/after summary. Audit data must not contain secrets, raw credentials, or unnecessary consumer personal information.

## 17. Error and recovery behavior

| Failure | Required behavior |
|---|---|
| Validation fails before submission | Keep working draft; show field-level errors; create no submitted version. |
| Permission or brokerage scope fails | Deny action without revealing existence of another brokerage's private record; record security-relevant denial where appropriate. |
| Approval transaction fails | Roll back the entire decision; public version remains unchanged; allow safe retry. |
| Publication projection fails after approval | Approved canonical state remains; mark publication job failed; retry idempotently; alert operations if threshold exceeded. |
| Notification delivery fails | Workflow decision remains valid; retry delivery and expose safe status to authorized users. |
| External destination fails | SteadFast publication remains valid; record destination-specific failure and retry under policy. |
| Agent eligibility changes during review | Re-evaluate at decision time; do not publish; route to Approved inactive or Unassigned as applicable. |
| Concurrent proposal conflict | Reject stale write with a clear refresh/rebase instruction; never silently overwrite. |
| Duplicate client request | Return the original idempotent result; do not create a second decision, share, or distribution send. |

## 18. Acceptance scenarios

1. An active agent creates, validates, submits, corrects, and obtains approval for a new public listing without training.
2. No initial listing is public while Draft, Pending initial approval, Changes requested, or Rejected.
3. A reviewer sees an exact before/after comparison and cannot silently edit the submitted snapshot.
4. A price change stays pending while the current approved price remains public; approval changes every SteadFast display atomically.
5. Rejection, return, or withdrawal of a material proposal leaves the current public version unchanged.
6. Staff without `listing.review` cannot approve through any interface, API, or direct database request.
7. Authorized staff who is also the submitting agent may self-approve, and the audit history identifies it.
8. Sold, rented, withdrawn, expired, archived, or unassigned listings disappear from active search, maps, sites, shares, and authorized feeds.
9. Agent departure removes brokerage access and public representation immediately without deleting the listing or agent account.
10. Reassignment selects only an active agent in the same brokerage and requires approval before republication.
11. Sharing gives the recipient display control only; attempts to edit, approve, reassign, or retrieve private listing data fail.
12. Shared pages show both agents, allow visitor selection, record the primary recipient, and notify both agents.
13. Approved listing changes update every active share and notify displaying agents.
14. Possible duplicate properties create broker-visible flags without automatic merge or rejection.
15. SteadFast operations can route and monitor a flag but cannot suspend or approve the listing.
16. A failed notification or external feed does not roll back a valid listing approval; each retries independently and visibly.
17. Duplicate approval, share, and delivery requests do not create duplicate business events.
18. Every significant action is traceable to actor, effective role, brokerage, listing/version, time, and decision reason where required.

## 19. Technical implementation handoff

The database and application architecture must implement:

- separate listing lifecycle and listing-version state fields;
- immutable submitted and approved snapshots;
- a current approved-version pointer;
- one-open-material-proposal constraint for the MVP;
- explicit allowed state transitions enforced server-side and in database functions where appropriate;
- brokerage ownership and time-bounded agent assignment;
- publication eligibility as a centralized deterministic policy;
- append-only audit and transactional outbox records;
- idempotency for approval, publication, notification, and distribution work;
- optimistic concurrency for working drafts;
- Row Level Security matching the approved Roles and Permissions Matrix;
- background projection jobs for search, maps, websites, shares, and feeds; and
- automated transition, permission, race-condition, and failure-recovery tests.

## 20. Open decisions

- Default listing expiry duration and extension rules.
- Whether an Under offer listing remains fully searchable or is shown only with reduced prominence.
- Whether share acceptance is mandatory or a grant becomes active immediately.
- Whether existing shares survive an approved representative change automatically or require new-owner confirmation.
- Exact minimum media and required-field rules by property type.
- Broker-controlled approximate public location policy, if privacy demand is confirmed.
- Whether sold/rented historical pages are publicly retained and for how long.
- Review reminders, escalation timing, and expected brokerage approval service levels.
- Destination-specific approval requirements and which subscriptions include each distribution channel.

## 21. Document governance

This workflow specification refines the MVP Product Requirements and Roles and Permissions Matrix without changing their approved business rules. Changes to ownership, approval authority, agent-departure behavior, sharing rights, SteadFast operational boundaries, or public eligibility require a recorded product decision and a new document version.

