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

## Phase 1 — Step 1: Azure CLI and subscription guardrails

Installed the Azure CLI inside WSL and authenticated with `az login --use-device-code`,
which avoids the browser-handoff problems WSL has with the default login flow. The
Debian package published for `jammy` installs cleanly on Ubuntu 26.04 — Microsoft does
not publish a package per Ubuntu codename.

Registered the resource providers needed by the phase before creating anything:
`Microsoft.App`, `Microsoft.DBforPostgreSQL`, `Microsoft.ContainerRegistry`,
`Microsoft.KeyVault` and `Microsoft.OperationalInsights`. A fresh subscription does not
have every provider enabled, and an unregistered provider surfaces as an obscure failure
halfway through a deployment rather than as a clear error up front. Registration is
asynchronous and free.

## Phase 1 — Step 2: Naming convention and resource group

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
