# PostureGuard

PostureGuard is a web application that scans user-submitted domains and generates a security posture report covering TLS, HTTP security headers, and open ports, with a 0-100 score and an A-F grade.

**Status:** Phase 1 complete. Deployed on Azure Container Apps and live at **[app.samdossou.com](https://app.samdossou.com)**. Terraform, Kubernetes, CI/CD, SOC integration and AWS are on the roadmap.

## Architecture

```mermaid
flowchart LR
    U[User] -->|HTTPS<br/>app.samdossou.com| ING[Container Apps ingress<br/>Azure-managed certificate]
    ING --> W[Web app<br/>Next.js 16<br/>scales to zero]
    W -->|read / write over TLS| DB[(Azure Database for<br/>PostgreSQL 16<br/>data + job queue)]
    WK[Worker<br/>Python<br/>no ingress] -->|claim jobs<br/>FOR UPDATE SKIP LOCKED| DB
    WK --> S1[TLS scanner]
    WK --> S2[HTTP headers scanner]
    WK --> S3[Port scanner]
    WK -->|findings + score| DB
    W -->|live report| U

    ACR[(Container Registry)] -.->|image pull| W
    ACR -.->|image pull| WK
    KV[(Key Vault)] -.->|secret reference| W
    KV -.->|secret reference| WK
    ID[Managed identity<br/>AcrPull + Secrets User] -.-> ACR
    ID -.-> KV
    W -.->|console logs| LOG[(Log Analytics)]
    WK -.->|console logs| LOG
```

The app enqueues scan jobs into a PostgreSQL table that doubles as a job queue. A separate Python worker claims jobs with `FOR UPDATE ... SKIP LOCKED`, runs the scanners, writes findings, computes a score, and marks the job done. The report page polls until the scan completes.

Neither component talks to the other directly. The database is the only channel between them. That is what allows the worker to have no ingress at all, and what will let it scale horizontally without coordination.

## Live deployment

Both components run as container apps in France Central:

- **Images** are pulled from Azure Container Registry using a user-assigned managed identity holding `AcrPull`. The registry's admin account is disabled, so no registry password exists anywhere in this project.
- **The connection string** is a Key Vault reference resolved at startup by the same identity, which holds `Key Vault Secrets User`, a read-only role. `DATABASE_URL` never appears in the application definition, and rotating the secret in the vault propagates with a restart.
- **The web app scales to zero** when idle and bills only on traffic, at the cost of a cold start of a few seconds. The worker runs a single replica while active.
- **Deployments are tagged with the short git SHA**, never `latest`. Container Apps keeps the previous revision active at zero traffic weight, so a rollback is one command.

Provisioning, start, stop, deploy and destroy are scripted in [`deploy/azure/`](deploy/azure/). The environment is meant to be destroyed between work sessions and rebuilt in minutes. See that directory's README for the operational notes.

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
- **Database:** PostgreSQL 16, run with Docker Compose locally, Azure Database for PostgreSQL Flexible Server in production
- **Worker:** Python (psycopg), standard-library scanners
- **Containers:** multi-stage builds, unprivileged users, Next.js standalone output (270 MB web image, 24 runtime packages)
- **Cloud:** Azure Container Apps, Container Registry, Key Vault, Log Analytics, Entra ID managed identities
- **Ops:** Azure CLI provisioning scripts; systemd service and backup timer for the local setup

## Getting started (local)

Prerequisites: Docker, Node.js 22+, Python 3.12+.

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
pip install -r requirements-dev.txt
python worker.py
```

## Security model

- Passwords are hashed with bcrypt; only the hash is stored.
- Sessions live server-side; the cookie holds only an opaque session id and is httpOnly.
- A domain must be verified via a DNS TXT record before it can be scanned, so users can only scan domains they control.
- No secret is stored in the repository, in a container image, or in an application definition. Secrets live in Key Vault and are read by a passwordless managed identity.
- Least privilege is applied and tested: the working account holds `Contributor` on a single resource group, not `Owner` on the subscription, and cannot grant itself permissions. The applications' identity can pull images but not push them, and read secrets but not write them.
- Container images run as unprivileged users, and `.dockerignore` excludes environment files, because Docker layers are immutable and a secret copied then deleted stays readable in the image history.

Known gaps are documented rather than hidden. The deployed application currently scores **58/100, grade D** against its own scanner. TLS is sound, but the security headers are missing. The database is reachable from Azure resources rather than from a private network. Both are Phase 2 work, and both are recorded in [`docs/report/phase-1-azure.md`](docs/report/phase-1-azure.md) with the reasoning behind the trade-off.

## Project structure

```
postureguard/
|-- web/                   # Next.js application
|   |-- app/               # pages, server actions, api routes
|   |-- lib/               # database pool, auth helpers
|   `-- Dockerfile         # multi-stage build, standalone output
|-- worker/                # Python worker
|   |-- worker.py          # main loop and scanners
|   |-- scoring.py         # scoring logic, isolated and tested
|   |-- test_scoring.py    # pytest unit tests
|   `-- Dockerfile
|-- db/init/01-schema.sql  # schema, auto-loaded on first start
|-- deploy/
|   |-- azure/             # provisioning, start, stop, deploy, destroy
|   `-- systemd/           # local worker service and backup timer
|-- scripts/backup-db.sh   # dump, gzip, rotate
|-- docker-compose.yml     # local PostgreSQL
`-- docs/
    |-- report/            # detailed build report, step by step
    |-- screenshots/       # annotated gallery
    |-- blog/              # published articles
    `-- blog-notes/        # session notes feeding future articles
```

## Documentation

- [Build report](docs/report/): every step, every decision, every trade-off, one file per phase
- [Screenshot gallery](docs/screenshots/README.md): annotated, in build order
- [Azure naming convention](docs/azure-naming-convention.md)
- [Deployment scripts](deploy/azure/README.md)

## Build log

| Phase | Status | What was built |
|---|---|---|
| [Phase 0](docs/report/phase-0-mvp.md) | Complete | MVP: authentication, DNS ownership verification, three scanners, scoring, plus systemd services and automated backups |
| [Phase 1](docs/report/phase-1-azure.md) | Complete | Azure foundation: identity hardening, hardened container images, managed PostgreSQL, Container Apps, custom domain, scripted cost control |
| Phase 2 | Next | Production hardening: security headers, private database networking, cookie and CORS scanners |

Each phase has its own report, written as the work happened rather than reconstructed afterwards. Mistakes and reversed decisions are kept in.

## Roadmap

Harden production and add cookie/CORS scanners (Phase 2); SOC integration with Microsoft Sentinel (Phase 3); refactor infrastructure to Terraform (Phase 4); run on Kubernetes with AKS (Phase 5); DevSecOps pipeline with GitLab CI (Phase 6); multi-cloud on AWS with EKS (Phase 7); GRC documentation against ISO 27001 and 27005 (Phase 8).

## License

MIT - see [LICENSE](LICENSE).

---

Built by Sam DOSSOU.
