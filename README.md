# PostureGuard

A web application that scans user-submitted domains and generates a security posture report (TLS, HTTP headers, open ports) with a 0-100 score and an A-F grade.

Status: in active development (Phase 0, MVP)

## Architecture

PostureGuard is built on a three-part architecture:

- Web app: Next.js 14 (App Router, TypeScript) with Server Actions
- Database: PostgreSQL 16 (also used as a job queue via SKIP LOCKED)
- Worker: Python service that polls the queue and runs the scans

## Scanners

- TLS: certificate and protocol analysis (sslyze)
- HTTP headers: security headers audit (httpx)
- Ports: open-port detection (raw sockets)

## Security model

- Email/password auth (bcrypt), server-side sessions, httpOnly cookies
- Domain ownership verified via DNS TXT record before scanning
- DNS re-verification at scan time (defense in depth)

## Getting started

Coming soon. Setup instructions will be added as the project is built.

## Roadmap

Multi-cloud deployment (Azure and AWS), IaC (Terraform), Kubernetes, CI/CD, and monitoring. Detailed roadmap to follow.

Built by Sam DOSSOU.
