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
require python3

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

PROM_URL="http://localhost:${PROMETHEUS_PORT:-9090}"

prom_result_count() {
  local q="$1"
  local raw
  raw="$(curl -fsS -G --data-urlencode "query=${q}" "${PROM_URL}/api/v1/query" 2>/dev/null || true)"
  printf "%s" "$raw" | python3 - <<'PY'
import json, sys
raw = sys.stdin.read().strip()
if not raw:
  print(0)
  raise SystemExit(0)
try:
  data = json.loads(raw)
except json.JSONDecodeError:
  print(0)
  raise SystemExit(0)
res = data.get("data", {}).get("result", [])
print(len(res))
PY
}

wait_for() {
  local timeout="$1"
  local interval="$2"
  local desc="$3"
  shift 3

  echo "Waiting: ${desc} (timeout ${timeout}s)..."
  local start
  start="$(date +%s)"
  while true; do
    if "$@"; then
      echo "OK: ${desc}"
      return 0
    fi
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
      echo "TIMEOUT: ${desc}"
      return 1
    fi
    sleep "$interval"
  done
}

ALERT_QUERY='ALERTS{alertname="DemoAppDown",alertstate="firing"}'

demo_health_ok() {
  curl -fsS "http://localhost:${DEMO_APP_PORT:-8088}/health" >/dev/null 2>&1
}

demo_health_down() {
  ! demo_health_ok
}

alert_is_firing() {
  [ "$(prom_result_count "${ALERT_QUERY}")" -ge 1 ]
}

alert_is_clear() {
  [ "$(prom_result_count "${ALERT_QUERY}")" -eq 0 ]
}

cleanup() {
  compose start demo-app >/dev/null 2>&1 || true
}
trap cleanup EXIT

WITH_EXTRAS=false
NO_PULL=false
NO_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --extras) WITH_EXTRAS=true ;;
    --no-pull) NO_PULL=true ;;
    --no-build) NO_BUILD=true ;;
  esac
done

echo "1) Ensuring stack is up..."
UP_NO_BUILD=""
if [ "$NO_BUILD" = true ]; then
  UP_NO_BUILD="--no-build"
fi

if [ "$WITH_EXTRAS" = true ] && [ "$NO_PULL" = true ]; then
  # shellcheck disable=SC2086
  bash scripts/up.sh --extras --no-pull $UP_NO_BUILD
elif [ "$WITH_EXTRAS" = true ]; then
  # shellcheck disable=SC2086
  bash scripts/up.sh --extras $UP_NO_BUILD
elif [ "$NO_PULL" = true ]; then
  # shellcheck disable=SC2086
  bash scripts/up.sh --no-pull $UP_NO_BUILD
else
  # shellcheck disable=SC2086
  bash scripts/up.sh $UP_NO_BUILD
fi
bash scripts/smoke-test.sh

echo
echo "2) Triggering incident (stop demo-app)..."
compose stop demo-app >/dev/null 2>&1 || true

wait_for 30 2 "demo-app /health DOWN" demo_health_down || true
wait_for 240 5 "DemoAppDown alert firing" alert_is_firing || {
  echo
  echo "Triage hints:"
  echo "- Prometheus:    http://localhost:${PROMETHEUS_PORT:-9090}"
  echo "- Alertmanager:  http://localhost:${ALERTMANAGER_PORT:-9093}"
  echo "- Demo health:   http://localhost:${DEMO_APP_PORT:-8088}/health"
  exit 1
}

echo
echo "3) Verify notification + dashboards:"
echo "- Alertmanager:  http://localhost:${ALERTMANAGER_PORT:-9093}"
echo "- Mailpit:       http://localhost:${MAILPIT_UI_PORT:-8025}"
echo "- Grafana:       http://localhost:${GRAFANA_PORT:-3000}"
echo

echo "4) Recovering (start demo-app)..."
compose start demo-app >/dev/null 2>&1 || true

wait_for 60 2 "demo-app /health OK" demo_health_ok
wait_for 240 5 "DemoAppDown alert cleared" alert_is_clear || true

echo
echo "5) Final smoke test..."
bash scripts/smoke-test.sh

echo
echo "Done."
