# PostureGuard: build progress report

Author: Sam DOSSOU
Project: PostureGuard (Phase 0, MVP)
Started: 2026-07-22

This report documents the build step by step, with screenshots stored in docs/screenshots/.

---

## Step 1: Dev environment

Environment: WSL2, Ubuntu 26.04, on Windows.

Installed and verified:
- Node.js v22.22.1
- npm 9.2.0
- Docker Compose v2.40.3
- Python 3.14.4
- Git 2.53.0

Notes: reset a forgotten WSL sudo password from Windows PowerShell using "wsl -d Ubuntu -u root" then "passwd". Installed docker-compose-v2 and nodejs from apt.

## Step 2: Project scaffolding and first commit

Actions:
- Created project at ~/projects/postureguard
- git init on branch main
- Created docs structure: blog-notes, security, screenshots, report
- Added .gitignore, README.md skeleton, day-1 blog note
- First commit: a14912c

Screenshot: docs/screenshots/01-first-commit.png

## Step 3: PostgreSQL via Docker Compose

Actions:
- Wrote docker-compose.yml (Postgres 16, healthcheck, named volume, port 5432)
- Added .env (gitignored secret) and .env.example (committed template)
- Wrote db/init/01-schema.sql: organizations, users, sessions, domains, scans, findings
- The scans table doubles as a job queue (status queued/running/done/error) for SKIP LOCKED polling
- Started the container: docker compose up -d, container healthy
- Verified the 6 tables were auto-created on first boot

Screenshot: docs/screenshots/02-db-schema.png

## Step 4: Next.js web app

Actions:
- Scaffolded the web app with create-next-app in web/ (Next.js 16, TypeScript, App Router, Tailwind CSS, ESLint)
- Verified the dev server boots on localhost:3000
- Replaced the default template with a custom PostureGuard landing page
- Added a screenshots gallery at docs/screenshots/README.md

Note: create-next-app installed Next.js 16 (newer than the planned 14); same App Router architecture. 3 npm audit warnings left untouched for now, to be handled in a dedicated dependency-security pass later.

Screenshots: docs/screenshots/03-nextjs-running.png, docs/screenshots/04-landing-page.png

## Step 5: Authentication

Actions:
- Connected Next.js to PostgreSQL via a pg connection pool (lib/db.ts) and a /api/health check
- Built email/password auth with bcryptjs (cost 12), server-side sessions, and an httpOnly session cookie (lib/auth.ts)
- Server Actions for signup, login, logout (app/actions/auth.ts)
- Signup creates the user AND their organization in a single transaction (minimal multi-tenant: one user = one org)
- Pages: /signup, /login, and a protected /dashboard that redirects unauthenticated visitors to /login
- Verified in DB that passwords are stored as bcrypt hashes ($2b$12$...)

Security note: the local DB password is still the placeholder value; acceptable for a local-only dev DB, to be rotated before the Azure deployment (Phase 1).

Screenshots: docs/screenshots/05-signup-page.png, 06-dashboard.png, 07-hashed-passwords.png

## Step 6: Domain submission and DNS TXT ownership verification

Actions:
- Added a domain submission form on the dashboard (with domain normalization and validation)
- Each domain gets a unique verification token (crypto random)
- Ownership is proven via a DNS TXT record at _postureguard.<domain> = postureguard-site-verification=<token>
- The Verify action performs a live DNS TXT lookup (Node dns/promises) and marks the domain verified only on a match
- Domains list shows Verified / Pending status per domain
- Tested add + failed verification (expected, since the TXT is not set on a domain we do not own)

Note: full green "Verified" flow requires a domain the user controls; will be exercised in Phase 1 with the blog domain.

Screenshot: docs/screenshots/08-domain-verification.png

## Step 7 and 8: Python worker, scanners, scoring, and report

Actions:
- Added a scan queue trigger (Scan now) that inserts a queued row into scans
- Built a live scan report page that auto-refreshes while a scan is queued or running
- Built the Python worker (worker/worker.py) in an isolated venv, dependencies: psycopg[binary], python-dotenv
- The worker claims one queued job at a time with FOR UPDATE ... SKIP LOCKED, so multiple workers never collide
- Three scanners (standard library only, no heavy deps):
  - TLS: certificate expiry and negotiated TLS version
  - HTTP headers: presence of HSTS, CSP, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
  - Ports: connect scan of common ports, flags sensitive ones (Telnet, RDP, MySQL, PostgreSQL, FTP)
- Scoring: start at 100, subtract per-severity penalties, map to an A-F grade
- End-to-end test on example.com: score 58/100 (grade D), 10 findings

Screenshots: docs/screenshots/09-scan-report.png, 10-worker-output.png

## Step 9: Linux production basics

Actions:
- Turned the Python worker into a systemd service (auto-start on boot, Restart=always, journald logging)
- Fixed Python stdout buffering under systemd with PYTHONUNBUFFERED and python -u so logs stream to journald
- Wrote a bash backup script (pg_dump + gzip) with rotation (keep last 7)
- Scheduled daily backups at 03:00 with a systemd timer (Persistent=true)
- Verified the worker service and backup timer survive a full machine restart (the timer ran automatically overnight)
- Versioned the unit files in deploy/systemd/ for reproducibility

Deferred: SSH hardening to Phase 1 on the Azure VM, where it is meaningful (WSL does not expose SSH to the internet).

Screenshots: docs/screenshots/11-systemd-worker.png, 12-backup-timer.png

## Phase 0 finish: scoring unit tests

Actions:
- Extracted the scoring logic into worker/scoring.py (no DB or network dependency, easy to test)
- worker.py now imports score_findings from that module
- Added worker/test_scoring.py with 5 pytest cases: empty scan (100/A), single high (80/B), single critical (60/C), realistic mix (58/D), and the zero floor (0/F)
- All 5 tests pass; verified the worker service still scans correctly after the refactor

Screenshot: docs/screenshots/13-tests-passing.png

## Phase 0 finish: first blog article (draft)

Wrote the first technical article, "Building a security posture scanner with Next.js and Python" (docs/blog/), in English and first person. It covers the architecture, the PostgreSQL SKIP LOCKED job queue, the scanners, DNS ownership verification, auth, and running the worker under systemd. It will be published once the Hugo blog is live in Phase 1.

Phase 0 is complete: full local MVP, worker as a systemd service with automated backups, README with an architecture diagram, MIT license, scoring unit tests, and this article.

## Phase 0 wrap-up: real domain verification

Registered samdossou.com (Cloudflare registrar) and verified ownership end to end:
the app generated a token, the TXT record (_postureguard.samdossou.com) was added at
the registrar, and PostureGuard's live DNS check confirmed it (green "Verified").
This validates the DNS ownership feature on a real domain, beyond the local example.com test.
The domain will host the deployed app and blog from Phase 1.

## Phase 1, Step 1: Azure CLI and subscription guardrails

Installed the Azure CLI inside WSL and authenticated with `az login --use-device-code`,
which avoids the browser-handoff problems WSL has with the default login flow. The
Debian package published for `jammy` installs cleanly on Ubuntu 26.04, since Microsoft does not publish a package per Ubuntu codename.

Registered the resource providers needed by the phase before creating anything:
`Microsoft.App`, `Microsoft.DBforPostgreSQL`, `Microsoft.ContainerRegistry`,
`Microsoft.KeyVault` and `Microsoft.OperationalInsights`. A fresh subscription does not
have every provider enabled, and an unregistered provider surfaces as an obscure failure
halfway through a deployment rather than as a clear error up front. Registration is
asynchronous and free.

## Phase 1, Step 2: Naming convention and resource group

Wrote the naming and tagging convention first (`docs/azure-naming-convention.md`) and
only then created infrastructure. The convention will be reused verbatim by the
Terraform code in Phase 4, so improvising names now would mean paying for a refactor
later.

All resource names live in `deploy/azure/00-variables.sh`, sourced by every deployment
script; no name is hard-coded in a command. The subscription ID is resolved at runtime
from the active CLI session instead of being committed, so the repository contains no
environment identifiers.

Created `rg-postureguard-prod-frc` in France Central with five mandatory tags
(`project`, `env`, `phase`, `owner`, `managedBy`). France Central gives the lowest
latency from Paris, keeps data in France, and has available quota on the trial
subscription. The whole phase deliberately lives in a single resource group: with a
credit that expires in 30 days, being able to delete everything with one command is a
cost control, not a shortcut.

## Phase 1, Step 3: Identity hardening and least privilege

Before deploying anything, I audited the identity layer of my own tenant. Listing role
assignments showed a single principal holding `Owner` on the entire subscription and
`Global Administrator` on the directory, with no separation between authority over
resources and authority over identities. The account name also carried the `#EXT#`
marker: the tenant's only administrator was an external identity backed by a personal
consumer account.

Entra ID security defaults were already enabled, so multifactor authentication was
enforced tenant-wide and legacy authentication protocols were blocked. Yet checking the
owning account itself showed two-step verification switched off, with its only
verification methods routing back to the same mailbox the account was tied to. The
tenant looked protected while its sole administrator was not. Remediated by registering
an authenticator app as an independent second factor, enabling two-step verification,
and storing an offline recovery code.

I then reconsidered the plan. My first instinct was to create a second Global
Administrator account to decouple administration from the consumer identity. Once the
original account had strong authentication, that would have added a password-based admin
account next to a passwordless, MFA-protected one: a weaker door beside a stronger one.

The design I settled on instead:

- the original account keeps `Owner` and `Global Administrator`, is strongly
  authenticated, and is used only for privileged operations such as granting roles;
- a dedicated working account, `sam.ops@…`, holds no directory role at all and exactly
  one RBAC assignment: `Contributor` scoped to `rg-postureguard-prod-frc`.

Two deliberate choices there. The scope is the resource group rather than the
subscription, so the account cannot see or touch anything else. And the role is
Contributor rather than Owner, so it can create and delete resources but cannot grant
permissions, including to itself.

Then I tested the boundary rather than assuming it. Signed in as the working account,
creating a resource group outside scope returns `AuthorizationFailed`; assigning itself
`Owner` returns `AuthorizationFailed`; listing resource groups returns exactly one. The
second denial is the one that matters, because it is what stops a compromised working
account from escalating. This is also the identity structure the CI/CD pipeline will
reuse in Phase 6, with federated credentials instead of a password.

Operational note: the initial password was passed through a shell variable read with
`read -rs`, so it never reached the shell history, and the account was created with
`--force-change-password-next-sign-in`, making that value disposable. Security defaults
then forced MFA registration at first sign-in, the policy proving itself on a new identity.

## Phase 1, Step 4: Key Vault and paying down the Phase 0 debt

Phase 0 shipped with a placeholder database password (`CHANGE_ME_strong_password`),
acceptable on a local database that was never exposed, unacceptable the moment anything
is deployed. The vault was therefore created before the database, so that the real
password never exists anywhere except inside it.

`kv-postureguard-prod` uses RBAC authorisation rather than legacy access policies, which
keeps permissions auditable in the same place as every other role assignment. Soft-delete
retention is set to the seven-day minimum, and purge protection is deliberately left off:
in production it should be enabled, since it prevents an attacker from permanently
destroying secrets, but here it would make the vault name unrecoverable after a
`az group delete` and break the tear-down-and-rebuild cycle the credit deadline demands.
That trade-off is documented rather than hidden.

Granting access to the vault contents required a separate role assignment even though the
account is subscription Owner. Azure separates the management plane (creating and configuring the vault) from the data plane (reading and writing secrets). Owner grants
the first, not the second. This is real protection: a compromised administrative account
does not automatically read the secrets.

The password itself is generated with `openssl`, piped through a filter that keeps only
alphanumeric characters, and written straight to the vault before being unset. The filter
is not cosmetic: PostgreSQL connection strings are URLs, and a password containing `@`,
`/`, `:` or `?` breaks them. The value is never printed, never stored in a file, and
never reaches shell history.

Operational note from this step: `az login --use-device-code`, the standard advice for
WSL, stopped working. Since 1 July 2026, newly created Entra tenants block device code
flow by default under security defaults, because the flow is heavily abused in phishing.
Interactive browser login is now the only path, which under WSL required a small helper
script exporting `BROWSER` so the CLI can hand the URL to the Windows browser.

## Phase 1, Step 5: Containerising the web app and the worker

Both components now build into images that run anywhere, take their configuration from the
environment, and contain no secrets.

Three principles were applied deliberately. The web image uses a three-stage build:
dependencies, build, runtime. Only the Next.js standalone output ships, which required
setting `output: "standalone"` in `next.config.ts`. The result is 270 MB rather than roughly
1.2 GB, and 24 runtime packages rather than the 386 installed at build time. Both images run
as unprivileged users, verified with `whoami` returning `nextjs` and `worker`. A container escape from root is an escape to root on the host. And `.dockerignore` excludes `.env*`
files: Docker layers are immutable, so a secret copied in one layer and deleted in the next
remains readable in the image history, which is one of the most common secret leaks in
practice.

`pytest` moved out of the worker's `requirements.txt` into `requirements-dev.txt`; test
tooling has no place in a production image. The worker needed no code changes:
`load_dotenv()` tolerates a missing file, and `os.environ["DATABASE_URL"]` reads whatever
the platform injects.

The dependency remediation took most of the step and is written up in full in the blog
notes. Summary: `npm ci` reported 12 high-severity advisories; inspecting the image showed
nine of them never leave the build stage. The one genuinely shipped package, `sharp 0.34.5`,
carried four libvips CVEs. `npm audit fix --force` proposed `next@9.3.3`, a six-year
downgrade, and was rejected. Installing `sharp@latest` only relocated the vulnerable copy
into `node_modules/next/node_modules/sharp`, where Node's resolution order would still have
preferred it. The correct fix was npm `overrides` with the `"$sharp"` syntax. Verified in
the artefact: the nested copy is gone, only 0.35.3 remains, and deduplicating the native binaries took the image from 305 MB to 270 MB in the process.

Both images were then tested against the local database. The first attempt pointed at
`host.docker.internal` and timed out, because the database is itself a container rather than
a host service; attaching the test containers to the same Docker network and addressing
PostgreSQL by service name worked immediately. That is the model Container Apps uses too,
and it demonstrates the point of the exercise: the same image runs locally and on Azure,
with only the environment variable changing.

The reflex this step taught: scan the artefact, not the lockfile. `npm audit` describes the
development tree, while an attacker interacts with the deployed image.

Operational note: WSL crashed mid-build with I/O errors across `/usr/bin`, taking Docker's
layer cache with it and leaving a dangling snapshot reference. `docker builder prune -af`
plus a `--no-cache` rebuild recovered it. An idle `kind` cluster from an unrelated project
was auto-restarting and consuming memory; stopping it removed the pressure.

## Phase 1, Step 6: Publishing the images to Azure Container Registry

`acrpostureguardprod` was created on the Basic tier with `--admin-enabled false`. ACR offers
a shared admin username and password valid across the whole registry, and it ends up pasted
into CI configuration and environment variables everywhere. Leaving it disabled means
authentication runs on Entra identities instead: an Entra token for pushing via
`az acr login`, and a managed identity for Container Apps to pull. No registry password will
exist in this project at any point.

The original plan was `az acr build`, which builds server-side and only uploads the build
context, which is cheaper on bandwidth and independent of the local machine's stability. It failed
with `TasksOperationsNotAllowed`: ACR Tasks is blocked on trial subscriptions, since managed
build agents are a standard target for cryptomining abuse. Filing a support request would
not change that, so the build stayed local and only the push went to Azure. A useful
reminder that a free tier is not a smaller paid tier, it is a different set of rules.

Each image carries two tags: the short git SHA of the commit that produced it, and `latest`.
Deployments will reference the SHA. Running `latest` in production means not knowing what is
actually deployed, and not being able to roll back with certainty during an incident. Both
tags share one digest, which is what allows verifying later that what is running matches the
commit.

Cost note: ACR Basic is the first billable resource in the phase, at roughly EUR 4.60 per
month. Unlike compute and the database, it will not be destroyed between sessions, because
it holds the images.

## Phase 1, Step 7: Azure Database for PostgreSQL

`psql-postureguard-prod` runs on the Burstable B1ms tier with 32 GB of storage, PostgreSQL 16
to match local development, seven-day backups and no geo-redundancy. Matching the local major
version deliberately: a version gap between development and production is not a variable
worth introducing during a first deployment. High availability is off, since it would double
the cost of a project where downtime has no consequence.

Three CLI surprises worth recording. `--high-availability` is rejected on Burstable, because
HA does not exist on that tier. `--database-name` is now reserved for elastic clusters, so
the database is created in a second command. And `--public-access None` does not mean "public
endpoint with no firewall rules" as I assumed. It disables public network access entirely,
which then makes firewall rules impossible to create. Inspecting `network.publicNetworkAccess`
before changing anything confirmed there was no VNet configuration to preserve. Public access
was enabled, and a single firewall rule scoped to one workstation IP was added. The result is
the intended posture: reachable only from an explicitly allowed address, over TLS only.

Loading the schema surfaced a managed-service constraint. `pgcrypto` is not allow-listed on
Azure Database for PostgreSQL, so `CREATE EXTENSION` failed while every table was still
created. Checking what the extension was actually used for showed it was only
`gen_random_uuid()`, which has been part of core PostgreSQL since version 13. The extension was a leftover reflex from PostgreSQL 12. Rather than allow-listing it via the
`azure.extensions` server parameter, the dependency was removed. A transactional insert with
`ROLLBACK` confirmed UUID defaults work without it. The schema is now portable to any managed
PostgreSQL 13+ with no server configuration required.

The full connection string, including `?sslmode=require`, is stored as a second Key Vault
secret rather than reassembled at each deployment. Encryption in transit becomes a property
of the secret instead of an option someone can forget to pass.

Cost note: this is the expensive resource of the phase at roughly EUR 13 per month running.
`az postgres flexible-server stop` reduces that to storage only between sessions; Azure
restarts a stopped server automatically after seven days.

## Phase 1, Step 8: Deploying to Azure Container Apps

PostureGuard is live. The web app answers on a public HTTPS endpoint from France Central,
having pulled its image from the registry with a passwordless identity, read its connection
string from Key Vault, and reached the managed database over TLS.

A Log Analytics workspace with thirty-day retention backs the Container Apps environment;
ingestion is free up to 5 GB per month, which is ample for two containers. It will also be
the data source for Sentinel in Phase 3.

The security model is the payoff of everything since step 3. A user-assigned managed identity
carries no password, since Azure issues tokens on demand, and holds exactly two roles: `AcrPull`
on the registry and `Key Vault Secrets User` on the vault. Not `AcrPush`, so it cannot publish
images. Not `Secrets Officer`, so it cannot create or modify secrets. `DATABASE_URL` is a
`secretRef` pointing at a Key Vault reference resolved at startup, so the connection string
never appears in the application definition, and rotating it in the vault propagates with a
restart.

The networking assumption I made at the start of the phase turned out to be wrong, and the
correction is the most interesting part of this step. I allowed the Container Apps
environment's `staticIp` through the PostgreSQL firewall; that address is the *inbound* IP.
Outbound traffic on a consumption environment leaves from a shared pool: `outboundIpAddresses` returned roughly 180 addresses, and that set changes over time. PostgreSQL Flexible Server
accepts 256 firewall rules, so IP allow-listing is not merely tedious here, it is unworkable.

Three options existed. Private VNet integration is the correct posture, but private access
cannot be enabled after creation on Flexible Server, so it would mean deleting and recreating
the server, rebuilding the environment inside a delegated subnet, and reloading the schema. A
NAT Gateway would give one stable egress IP and a single firewall rule, at roughly EUR 30 per
month, doubling the phase budget against a EUR 175 credit. I chose the third: the
`AllowAzureServices` rule, which is the Azure convention of a `0.0.0.0` start and end address
and means "reachable from Azure resources", not "reachable from the internet".

Being precise about what that costs: the attack surface widens from one address to the Azure
range, including resources in other tenants. What it does not do is weaken authentication: a 32-character random password from Key Vault over enforced TLS. The residual risk is bounded
and documented rather than hidden, and closing it properly is scheduled for Phase 2, which
gives that work a measurable before and after.

Cost discipline: the web app runs with `--min-replicas 0`, so it bills only when someone
visits, at the price of a twenty-second cold start. The worker needs a permanent replica while
working and is scaled to zero between sessions. Two apps left running at 0.5 and 0.25 vCPU
would consume far beyond the monthly free grant of 180,000 vCPU-seconds and cost around EUR 40
per month, which would exhaust the credit in five weeks.

## Phase 1, Step 9: Custom domain and managed certificate

`app.samdossou.com` now serves the application over HTTPS with an Azure-managed certificate.
Two DNS records at Cloudflare: a CNAME from `app` to the container app's default hostname, and
a TXT record at `asuid.app` carrying the app's `customDomainVerificationId`. The `asuid`
convention exists so that a platform never attaches a service to a hostname the requester
cannot prove they control.

The Cloudflare proxy is set to "DNS only" on purpose. With the proxy enabled, Cloudflare
terminates TLS and presents its own certificate, which prevents Azure from validating domain
ownership. The subtler risk is the renewal: Azure revalidates the CNAME when the managed
certificate expires, so a proxy enabled later would break the site with a certificate error
months after the change that caused it. When the Cloudflare WAF arrives in Phase 2, that
becomes a real architectural choice between the Azure managed certificate and TLS termination
at the edge.

Verified end to end: `HTTP 200` with `ssl_verify_result 0`, meaning the full chain validates
from a client that trusts no private authority.

## Phase 1, Step 10: Observability, and what it immediately found

`az containerapp logs show` is convenient for debugging but only reads the recent buffer of a
live replica; once a container restarts or scales to zero, those lines are gone. Log Analytics
keeps thirty days independently of container lifecycle, and querying it is the part that matters, because a workspace nobody knows how to search is useless during an incident.

The first KQL query returned a defect I had not noticed. The worker was logging
`psycopg.errors.ConnectionTimeout` repeatedly after the database was stopped: `worker.py`
opens a single connection at startup and the process exits if it fails, so the platform
restarts it, and it fails again. Locally systemd restarted it the same way, which is exactly
why the defect had stayed invisible through all of Phase 0.

The aggregate query made the anomaly visible without reading any individual line: 178 events
from a background worker against 42 from the web app actually serving traffic. A silent
process talking four times more than a public endpoint is the signal itself. That is detection
reasoning rather than log reading, and the language is the same KQL that Sentinel uses in
Phase 3.

Two corrections followed. First, `--min-replicas 0` does not stop an app without ingress. `az containerapp replica list` showed the replica still running and still crashing.
Deactivating the revision is the reliable off switch, and that is what belongs in the stop
script rather than a scale setting. A cost control you have not verified is not a cost control.
Second, the resilience gap is now recorded as known debt: the worker needs reconnection with
exponential backoff so that a maintenance failover or a thirty-second network blip does not
leave it crash-looping until someone notices. Roughly twenty lines of code, scheduled with the
production hardening work in Phase 2.

## Phase 1, Step 11: Cost control as code

Six scripts in `deploy/azure/` turn the environment into something rented rather than
owned: `10-provision.sh` builds everything from nothing and is idempotent, `20-start.sh`
and `30-stop.sh` bracket a work session, `40-update-images.sh` ships a commit, and
`90-destroy.sh` removes every resource behind a typed confirmation. They are the draft of
the Phase 4 Terraform configuration, using the same names and tags.

Three details carry the lessons of this phase. `30-stop.sh` deactivates the worker's
revision rather than setting `--min-replicas 0`, because an app without ingress has no
scale trigger and the scale setting alone left the replica running and crash-looping. A cost control that had not been verified was not a cost control. `20-start.sh` refreshes
the workstation firewall rule on every run, since a residential IP changes and a stale
rule is indistinguishable from a broken database. And `40-update-images.sh` refuses to
deploy from a dirty working tree: images are tagged with the short git SHA, so if local
code differs from the commit the tag is a lie and the traceability built in step 6 is
worthless.

The full provisioning script was validated with `bash -n` rather than executed. Testing it
honestly requires destroying the environment first, which belongs at the end of the phase
as the final verification, not in the middle of it.

## Phase 1, Step 12: End-to-end verification

The deployment was verified by using the application, not by querying Azure. An account was
created on the live instance, `samdossou.com` was added and its ownership proven through a
real DNS TXT record, and a scan was queued from the browser. The worker in France Central
picked the job up, ran the three scanners and wrote the findings in about one second. The
queue-as-database design from Phase 0, with `FOR UPDATE ... SKIP LOCKED`, works unchanged on
Container Apps.

The first scan produced two findings I did not expect. Scanning the apex returned `No address
associated with hostname`: `samdossou.com` has no A, AAAA or CNAME record, so the bare domain
reaches nothing. The scanner was correct, and it had found a real gap in my own DNS on the day of deployment, after I had bound a certificate and verified HTTPS without ever noticing that
the apex led nowhere. The second is a scoring flaw: a domain that does not resolve at all
scores 70/100, grade C, because the scanner applies "TLS failed" and "headers unreachable"
penalties as though it had measured something weak when in fact it measured nothing.
"Misconfigured" and "unassessable" are different states and should not share a grade band.
Phase 0 tested against `example.com` and a local database; real use surfaced this in seconds.

Scanning the deployed application itself gave the meaningful result: `app.samdossou.com`
scores 58/100, grade D. TLS 1.3 with a valid certificate, a layer Azure manages well, and five missing security headers, HSTS as the single high finding. The arithmetic matches the
scoring module exactly: 100 minus 20 for the high, 10 for the medium and 12 for three lows.

The D stays. Fixing the headers is fifteen lines in `next.config.ts` and the deployment
pipeline is already in place, but the honest Phase 1 result is the measurable starting point
for the production hardening in Phase 2. A documented before and after is worth more than a
quietly obtained A.
