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

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }
}

require curl

echo "Checking demo-app..."
curl -fsS "http://localhost:${DEMO_APP_PORT:-8088}/health" >/dev/null

echo "Checking Prometheus..."
curl -fsS "http://localhost:${PROMETHEUS_PORT:-9090}/-/ready" >/dev/null

echo "Checking Grafana..."
curl -fsS "http://localhost:${GRAFANA_PORT:-3000}/api/health" >/dev/null

echo "OK"
