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
