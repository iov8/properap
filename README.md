# SteadFast Realty

SteadFast is a cloud platform for Jamaican real estate brokerages, broker staff, and agents to create, approve, publish, share, and manage property listings. The public website lets visitors and registered consumers search listings and contact an agent.

## Project status

The project is in the foundation and prototype stage. Product requirements, business documents, and the initial technical plan are available in [`docs`](./docs/README.md).

## Initial platform

- Next.js with TypeScript for the web application
- Supabase for PostgreSQL, authentication, storage, and Row Level Security
- Vercel for preview and production deployments
- GitHub for source control and deployment triggers
- `steadfast.rockhillinnovation.com` as the initial public address

The architecture must remain portable so the application can later run outside Vercel or Supabase where practical.

## User areas

- Public property search for visitors and registered consumers
- Agent workspace for listing creation and management
- Broker staff workspace for listing approvals and agent management
- Broker workspace for brokerage, staff, agent, and listing administration
- SteadFast operations workspace for customer service, subscriptions, and platform monitoring
- SteadFast administration workspace for full system administration

## Core business rules

- A brokerage is the main organizational owner of listings.
- An agent belongs to one brokerage at a time and requires broker approval, followed by SteadFast account approval.
- New listings, price changes, major edits, removal, and sold status require brokerage approval.
- Agents may advertise another agent's approved listing without changing it.
- Shared listings show both the advertising agent and listing owner's agent as contact choices.
- Listings require an active representing agent. When an agent leaves a brokerage, their listings are unpublished until reassigned and approved.
- Every approval, rejection, resubmission, and material change must be retained in an audit log.

## Deployment workflow

1. Work is committed to a Git branch.
2. GitHub receives the branch or pull request.
3. Vercel creates a preview deployment for review.
4. Approved changes are merged into `main`.
5. Vercel deploys `main` to the production domain.

No `.env` file or secret key may be committed. Deployment secrets belong in Vercel's encrypted environment settings.

## Repository layout

```text
app/      Next.js routes and user-facing pages
docs/     Product, business, and technical documentation
lib/      Shared application and service integrations
public/   Trusted static brand assets
tools/    Utilities used to generate and maintain documentation
```

## Documentation

Start with the [documentation index](./docs/README.md). Future technical documentation should be updated in the same change as the feature it describes.

## Security

Review [SECURITY.md](./SECURITY.md) before handling credentials, authentication, authorization, uploads, listing feeds, or payments.
