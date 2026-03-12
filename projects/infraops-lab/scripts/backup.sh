#!/usr/bin/env bash
set -euo pipefail

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

ts="$(date -u +%Y%m%dT%H%M%SZ)"
compose --profile tools run --rm restic backup /data --tag "infraops-lab" --tag "$ts"
compose --profile tools run --rm restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
