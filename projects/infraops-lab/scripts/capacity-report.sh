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

PROM_URL="${PROM_URL:-http://localhost:${PROMETHEUS_PORT:-9090}}"

query() {
  local q="$1"
  python3 - <<PY
import json, sys, urllib.parse, subprocess
prom = ${PROM_URL!r}
q = ${q!r}
url = prom + "/api/v1/query?query=" + urllib.parse.quote(q, safe="")
raw = subprocess.check_output(["curl","-fsS",url])
data = json.loads(raw)
if data.get("status") != "success":
  print("query_failed", file=sys.stderr)
  sys.exit(1)
for r in data["data"]["result"]:
  metric = r.get("metric", {})
  name = metric.get("name") or metric.get("container") or metric.get("instance") or metric.get("__name__") or "unknown"
  value = r.get("value", ["", ""])[1]
  print(f"{name}\t{value}")
PY
}

echo "Top CPU (container rate/sec, 5m window):"
query 'topk(10, sum(rate(container_cpu_usage_seconds_total{image!=""}[5m])) by (name))' || true
echo
echo "Top memory (bytes):"
query 'topk(10, max(container_memory_working_set_bytes{image!=""}) by (name))' || true
