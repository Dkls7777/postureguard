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
