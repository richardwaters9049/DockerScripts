# Docker Script Guide: `docker-nextpy`

> A fast project generator for a full-stack Docker dev environment.

## Table of Contents

- [Project Overview](#project-overview)
- [Project Aim](#project-aim)
- [What This Script Builds](#what-this-script-builds)
- [Expected Output](#expected-output)
- [How the Script Works](#how-the-script-works)
- [Why It Helps Developers](#why-it-helps-developers)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Generated Project Structure](#generated-project-structure)
- [Key Startup Logic (Bug Fix Included)](#key-startup-logic-bug-fix-included)
- [Troubleshooting](#troubleshooting)
- [Customization Ideas](#customization-ideas)

## Project Overview

`docker-nextpy` is a Bash automation script that scaffolds and launches a modern full-stack app with:

- `FastAPI` backend (Python)
- `Prisma` ORM (`prisma-client-py`)
- `PostgreSQL` database
- `Next.js` frontend (created with `Bun`)
- `Docker Compose` orchestration

The script creates files, wires services together, and boots everything locally in one flow.

## Project Aim

The goal is to reduce setup friction and speed up delivery by giving developers:

- A ready-to-run full-stack baseline
- A reproducible local environment with Docker
- Pre-wired backend, DB, and frontend integration
- Starter routes, seed data, and tests for fast iteration

## What This Script Builds

### Backend

- FastAPI app entrypoint (`/`, `/users`, `/training`)
- Prisma schema and generated client usage
- Seed script with starter users and training data
- Basic async test file
- Dockerfile for backend container

### Frontend

- Next.js app scaffolded with Bun
- Starter dashboard page that fetches backend users
- Animation/UI helpers (`framer-motion`, `clsx`)

### Infrastructure

- `docker-compose.yml` with `db`, `backend`, and `frontend`
- Postgres healthcheck and service dependencies

## Expected Output

After running the script successfully:

- A new project folder named after your argument
- Running containers for database, backend, and frontend
- Reachable local URLs:
  - Frontend: `http://localhost:3000`
  - Backend users endpoint: `http://localhost:8000/users`
  - Backend docs: `http://localhost:8000/docs`
- Seeded initial records in PostgreSQL

## How the Script Works

1. Reads project name argument and validates input.
2. Shows an interactive conflict handler for existing directories:
   - `Overwrite`
   - `Keep`
   - `Delete`
3. Writes backend files (schema, API, hooks, seed, tests, Dockerfile).
4. Optionally scaffolds frontend via `bun create next-app`.
5. Writes `docker-compose.yml`.
6. Builds and runs all containers.
7. Waits for DB readiness and prints success URLs.

## Why It Helps Developers

- Faster bootstrapping for new ideas and prototypes
- Consistent local setup across team members
- Lower onboarding time for new contributors
- Clear starting architecture that can scale with features
- Less manual wiring between API, database, and UI

## Prerequisites

- Docker + Docker Compose
- Bun installed locally
- Bash-compatible shell

## Usage

```bash
chmod +x docker-nextpy.sh
./docker-nextpy.sh my-project
```

Replace `docker-nextpy.sh` with your actual script filename.

## Generated Project Structure

```text
my-project/
├── backend/
│   ├── app/
│   │   ├── hooks/
│   │   ├── tests/
│   │   ├── database.py
│   │   └── main.py
│   ├── prisma/
│   │   └── schema.prisma
│   ├── Dockerfile
│   ├── requirements.txt
│   └── seed.py
├── frontend/
│   ├── app/
│   │   └── page.tsx
│   ├── package.json
│   └── next.config.js
└── docker-compose.yml
```

## Key Startup Logic (Bug Fix Included)

Backend container startup uses:

```sh
prisma generate && prisma db push && python seed.py && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Why this matters:

- `prisma migrate deploy` fails to create tables when no migration files exist.
- `prisma db push` creates tables directly from `schema.prisma`.
- This prevents `TableNotFoundError` during `seed.py`.

## Troubleshooting

Check service logs:

```bash
docker-compose logs -f db
docker-compose logs -f backend
docker-compose logs -f frontend
```

Rebuild cleanly if needed:

```bash
docker-compose down -v
docker-compose up -d --build
```

## Customization Ideas

- Add auth and role models to Prisma schema
- Replace seed values with domain-specific fixtures
- Switch frontend from starter page to your app shell
- Add CI with lint/test/build checks
- Move from `db push` to migration workflow when schema stabilizes
