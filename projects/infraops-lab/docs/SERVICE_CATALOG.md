# Service Catalog (Infra Ops Lab)

## Core services

- `prometheus` — Metrics collection and alert rule evaluation.
- `alertmanager` — Alert routing to email (Mailpit).
- `grafana` — Dashboards; data sources provisioned for Prometheus + Loki.
- `loki` — Log store queried from Grafana.
- `vector` — Collects Docker logs and ships them to Loki.
- `minio` — S3-compatible object storage (used as Restic backend).

## Supporting services

- `cadvisor` — Container metrics for capacity/behaviour insight.
- `blackbox` — Synthetic probes for service availability.
- `demo-app` — Metrics-emitting app with failure injection (incident drill target).
- `loadgen` — Generates steady traffic to demo-app.
- `mailpit` — Local SMTP + web UI for alert notifications.
- `restic` — One-shot backup/restore tool (profile: `tools`).
