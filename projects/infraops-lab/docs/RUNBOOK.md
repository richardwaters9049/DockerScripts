# Runbook (Infra Ops Lab)

## Start / Stop

- Start: `bash scripts/up.sh`
- Start (+cAdvisor extras): `bash scripts/up.sh --extras`
- Stop: `bash scripts/down.sh`
- Smoke test: `bash scripts/smoke-test.sh`
- Interview demo drill: `bash scripts/demo.sh`

## Alert drill (simulate an incident)

1. Confirm metrics ingest: open Prometheus UI and search for `up`.
2. View email alerts: open Mailpit UI.
3. Break the service:
   - `docker compose stop demo-app`
4. Observe:
   - Prometheus: `up{job="demo-app"}` drops to `0`
   - Alertmanager: `DemoAppDown` fires after 2 minutes
   - Mailpit: receives alert email
5. Restore service:
   - `docker compose start demo-app`

## Backup / Restore drill (DR)

1. Initialise repo (first time):
   - `bash scripts/backup-init.sh`
2. Create snapshot:
   - `bash scripts/backup.sh`
3. Restore latest snapshot to local folder:
   - `bash scripts/restore-latest.sh`

## Triage checklist (3rd-line mindset)

- Identify blast radius (which services / which users)
- Validate monitoring signal (is it real vs noisy?)
- Check logs (Grafana → Loki)
- Mitigate (restart/rollback) and confirm recovery
- Capture timeline and permanent fix action

## Useful tooling

- Triage snapshot bundle: `bash scripts/triage-bundle.sh`
- Capacity snapshot (Prometheus API): `bash scripts/capacity-report.sh`
