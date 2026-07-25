# PostureGuard: build screenshots

A visual, step-by-step log of building PostureGuard. Each screenshot documents a milestone.

## 01. First commit
![First commit](01-first-commit.png)

Initialized the Git repository and made the first commit: .gitignore, README skeleton, and day-1 notes. This is the official start of the project.

## 02. Database schema
![Database schema](02-db-schema.png)

PostgreSQL 16 running in Docker. The six core tables (organizations, users, sessions, domains, scans, findings) were auto-created on first boot from the init SQL script. The scans table doubles as a job queue.

## 03. Next.js app running
![Next.js running](03-nextjs-running.png)

The Next.js 16 web app boots on localhost:3000 with the default template, confirming the frontend toolchain works.

## 04. PostureGuard landing page
![Landing page](04-landing-page.png)

Replaced the default template with a custom PostureGuard landing page, styled with Tailwind CSS.

## 05. Sign-up page
![Sign-up page](05-signup-page.png)

The account creation form (email + password), styled with Tailwind.

## 06. Dashboard (protected)
![Dashboard](06-dashboard.png)

After sign-up or login, the user lands on a protected dashboard. Unauthenticated visitors are redirected to the login page.

## 07. Hashed passwords in the database
![Hashed passwords](07-hashed-passwords.png)

Passwords are never stored in plain text. Each is hashed with bcrypt (cost factor 12), shown here by the "$2b$12$" prefix.

## 08. Domain ownership verification
![Domain verification](08-domain-verification.png)

Before scanning, a user must prove they own the domain. PostureGuard issues a unique token to place in a DNS TXT record (_postureguard.<domain>). Verification performs a live DNS lookup and only marks the domain verified if the token is found.

## 09. Scan report
![Scan report](09-scan-report.png)

A completed scan for example.com: overall score 58/100 (grade D) with detailed findings across TLS, HTTP headers, and open ports.

## 10. Python worker
![Worker output](10-worker-output.png)

The Python worker polls the scans queue (SKIP LOCKED), runs the three scanners, writes findings, computes the score, and marks the scan done.

## 11. systemd worker service
![systemd worker](11-systemd-worker.png)

The Python worker runs as a systemd service: it starts automatically on boot, restarts on crash, and its logs are captured by journald.

## 12. Automated database backups
![Backup timer](12-backup-timer.png)

A systemd timer runs a bash backup script daily at 03:00. Each run dumps and gzips the database, then rotates old backups (keeping the last 7). The timer fired on its own after a full machine restart.

## 13. Scoring unit tests
![Scoring tests](13-tests-passing.png)

The scoring logic is isolated in a dependency-free module and covered by pytest unit tests: empty scan, single high, single critical, a realistic mixed case, and the zero floor.

## 14. Real domain ownership verified
![Real domain verified](14-real-domain-verified.png)

End-to-end ownership verification on a real domain I own (samdossou.com): the app issued a unique token, I added the corresponding DNS TXT record at the registrar (Cloudflare), and the live DNS lookup confirmed it. The badge turned green.
