#!/usr/bin/env bash
set -euo pipefail

load_env() {
  if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    . ".env"
    set +a
  fi
}

load_env

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

mkdir -p backups
ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="backups/triage-$ts.txt"

{
  echo "# InfraOps Lab triage bundle"
  echo "timestamp_utc=$ts"
  echo
  echo "## docker"
  docker version || true
  echo
  echo "## compose"
  docker compose version 2>/dev/null || docker-compose version 2>/dev/null || true
  echo
  echo "## compose ps"
  compose ps || true
  echo
  echo "## health checks"
  curl -fsS "http://localhost:${DEMO_APP_PORT:-8088}/health" >/dev/null && echo "demo-app=ok" || echo "demo-app=fail"
  curl -fsS "http://localhost:${PROMETHEUS_PORT:-9090}/-/ready" >/dev/null && echo "prometheus=ok" || echo "prometheus=fail"
  curl -fsS "http://localhost:${GRAFANA_PORT:-3000}/api/health" >/dev/null && echo "grafana=ok" || echo "grafana=fail"
  echo
  echo "## recent logs (tail 120)"
  for svc in prometheus alertmanager grafana loki vector demo-app minio; do
    echo
    echo "--- service=$svc ---"
    compose logs --tail 120 "$svc" 2>/dev/null || true
  done
} >"$out"

echo "Wrote $out"
