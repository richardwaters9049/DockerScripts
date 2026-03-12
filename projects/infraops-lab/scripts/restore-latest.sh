#!/usr/bin/env bash
set -euo pipefail

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

mkdir -p backups/restore-latest
compose --profile tools run --rm restic restore latest --target /restore/restore-latest
echo "Restored into ./backups/restore-latest"
