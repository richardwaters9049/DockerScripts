# infraops-lab

Infra Ops Lab: metrics, logging, alerting, and backup/restore using Docker Compose.

## Why this is “3rd-line infra” aligned

- Incident drills (simulate service down / elevated 5xx → alert → triage → recovery)
- Monitoring + synthetic probes (Prometheus + blackbox exporter)
- Logging pipeline (Vector → Loki → Grafana)
- DR basics (Restic encrypted snapshots to S3-compatible MinIO + restore workflow)
- Documentation/runbooks (service catalog + postmortem template)

## Quick start

```bash
cp .env.example .env
# edit secrets/ports if desired

bash scripts/up.sh
bash scripts/smoke-test.sh
```

## Start without rebuild/pull (if already running once)

```bash
bash scripts/up.sh --no-build --no-pull
```

## One-command incident demo (interview)

```bash
bash scripts/demo.sh
```

## If your network blocks Docker registries

Create an offline image cache on a network that can pull images:

```bash
bash scripts/cache-images.sh backups/images-cache.tar
```

Then on the restricted network, keep that file next to the project and run:

```bash
IMAGES_CACHE_PATH=backups/images-cache.tar bash scripts/up.sh --no-pull
```

## Optional: container-level CPU/memory metrics

This uses cAdvisor (extra profile). Some networks block pulling from GHCR.

```bash
bash scripts/up.sh --extras
```

## What this demonstrates

- Monitoring: Prometheus + cAdvisor + blackbox probes
- Alerting: Alertmanager → Mailpit (local SMTP inbox)
- Logging: Vector (Docker logs) → Loki → Grafana
- Object storage: MinIO (S3-compatible)
- Backups: Restic snapshots to MinIO + restore flow

## Security defaults

- All UIs bind to `127.0.0.1` (not exposed to your LAN by default).
- Secrets live in `.env` and are gitignored; commit `.env.example` only.

See `docs/RUNBOOK.md`, `docs/SERVICE_CATALOG.md`, and `docs/POSTMORTEM_TEMPLATE.md`.
