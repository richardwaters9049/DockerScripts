#!/usr/bin/env bash
set -euo pipefail

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

compose --profile tools run --rm restic snapshots >/dev/null 2>&1 && {
  echo "Restic repo already initialised."
  exit 0
}

compose --profile tools run --rm restic init
