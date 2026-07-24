# PostureGuard

PostureGuard is a web application that scans user-submitted domains and generates a security posture report covering TLS, HTTP security headers, and open ports, with a 0-100 score and an A-F grade.

**Status:** Phase 0 (MVP) complete and running locally. Multi-cloud deployment, IaC, Kubernetes, CI/CD, and SOC integration are on the roadmap.

## Architecture

```mermaid
flowchart LR
    U[User] -->|sign up, add domain, request scan| W[Next.js web app]
    W -->|read / write| DB[(PostgreSQL 16<br/>data + job queue)]
    WK[Python worker] -->|poll queued jobs<br/>FOR UPDATE SKIP LOCKED| DB
    WK --> S1[TLS scanner]
    WK --> S2[HTTP headers scanner]
    WK --> S3[Port scanner]
    WK -->|write findings + score| DB
    W -->|render live report| U
```

The app enqueues scan jobs into a PostgreSQL table that doubles as a job queue. A separate Python worker claims jobs with `FOR UPDATE ... SKIP LOCKED`, runs the scanners, writes findings, computes a score, and marks the job done. The report page polls until the scan completes.

## Features

- Email/password authentication (bcrypt), server-side sessions, httpOnly cookie
- Minimal multi-tenancy: one user maps to one organization
- Domain submission with DNS TXT ownership verification
- Asynchronous scanning via a PostgreSQL-backed job queue
- Three scanners: TLS (certificate + protocol), HTTP security headers, open ports
- Scoring (0-100) and grade (A-F) with per-finding severity
- Live scan report that refreshes while a scan runs

## Tech stack

- **Web:** Next.js 16 (App Router, TypeScript), Server Actions, Tailwind CSS
- **Database:** PostgreSQL 16 (Docker Compose)
- **Worker:** Python (psycopg), standard-library scanners
- **Ops:** systemd service for the worker, systemd timer for daily backups

## Getting started (local)

Prerequisites: Docker, Node.js 20+, Python 3.12+.

```bash
# 1. Database
cp .env.example .env        # set POSTGRES_PASSWORD
docker compose up -d

# 2. Web app
cd web
npm install
echo "DATABASE_URL=postgresql://postureguard:YOUR_PASSWORD@localhost:5432/postureguard" > .env.local
npm run dev                 # http://localhost:3000

# 3. Worker (in another terminal)
cd worker
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python worker.py
```

## Security model

- Passwords are hashed with bcrypt; only the hash is stored.
- Sessions live server-side; the cookie holds only an opaque session id and is httpOnly.
- A domain must be verified via a DNS TXT record before it can be scanned, so users can only scan domains they control.

## Project structure
## Roadmap

Deploy to Azure (Container Apps), then AWS (EKS); refactor infrastructure to Terraform; run on Kubernetes; add a DevSecOps CI/CD pipeline; integrate a SOC (Microsoft Sentinel); add more scanners (cookies, CORS, software versions, SPF/DKIM/DMARC).

## License

MIT - see [LICENSE](LICENSE).

---

Built by Sam DOSSOU.
