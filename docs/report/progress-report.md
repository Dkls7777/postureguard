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
