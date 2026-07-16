# Security policy

Security is part of every SteadFast feature because the platform handles identities, brokerage data, listings, customer enquiries, and payments.

## Reporting a security issue

Do not publish suspected vulnerabilities in a public GitHub issue. Report them privately to the SteadFast project owner. A dedicated security contact will be added before public launch.

## Secrets and environments

- Never commit passwords, tokens, private keys, service-role keys, database credentials, or `.env` files.
- Store deployment secrets in Vercel environment settings and restrict production access.
- Only browser-safe configuration may use the `NEXT_PUBLIC_` prefix.
- The Supabase service-role key is server-only and must never be included in browser code.
- Rotate any credential immediately if it is exposed in source, logs, screenshots, or chat.

## Application baseline

- Enforce authorization on the server and with Supabase Row Level Security; hiding a button is not authorization.
- Validate all request data at runtime before using it.
- Use random UUIDs for public resource identifiers.
- Keep authenticated and user-specific responses out of shared caches.
- Validate listing uploads by size and actual content type and store them in private or policy-controlled storage.
- Use strict allowlists for redirects, webhooks, feeds, and external API destinations.
- Keep audit logs for approvals and material listing changes.
- Apply rate limits to login, registration, password reset, contact, upload, and integration endpoints.
- Never log passwords, session tokens, authorization headers, cookies, or full environment values.

## Dependency and release safety

- Commit the package lockfile and use reproducible installs in automated builds.
- Keep Next.js, React, Supabase libraries, and other dependencies on supported security-patched releases.
- Review automated dependency alerts before merging upgrades.
- Require successful automated checks and a preview review before production deployment.

