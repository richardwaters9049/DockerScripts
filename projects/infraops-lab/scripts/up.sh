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

port_available() {
  local port="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$port" <<'PY'
import socket, sys
port = int(sys.argv[1])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
  s.bind(("127.0.0.1", port))
except OSError:
  raise SystemExit(1)
finally:
  try:
    s.close()
  except Exception:
    pass
raise SystemExit(0)
PY
    return $?
  fi
  return 0
}

random_free_port() {
  python3 - <<'PY'
import socket
import sys
try:
  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  s.bind(("127.0.0.1", 0))
  print(s.getsockname()[1])
  s.close()
except OSError:
  raise SystemExit(1)
PY
}

# Bash 3.2 + `set -u` treats empty arrays as "unbound" on expansion.
# Seed with an empty element so "${RESERVED_PORTS[@]}" is always defined.
RESERVED_PORTS=("")

port_reserved() {
  local port="$1"
  local reserved
  for reserved in "${RESERVED_PORTS[@]}"; do
    [ -z "$reserved" ] && continue
    [ "$reserved" = "$port" ] && return 0
  done
  return 1
}

reserve_port() {
  local port="$1"
  RESERVED_PORTS+=("$port")
}

set_env_kv() {
  local key="$1"
  local value="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$key" "$value" <<'PY'
import pathlib, sys
key, value = sys.argv[1], sys.argv[2]
path = pathlib.Path(".env")
lines = path.read_text().splitlines() if path.exists() else []
out = []
found = False
for line in lines:
  if line.startswith(key + "="):
    out.append(f"{key}={value}")
    found = True
  else:
    out.append(line)
if not found:
  out.append(f"{key}={value}")
path.write_text("\n".join(out) + "\n")
PY
    return 0
  fi

  # Fallback: append only (won't overwrite existing keys)
  printf "%s=%s\n" "$key" "$value" >> .env
}

ensure_port_free() {
  local key="$1"
  local label="$2"
  local preferred="${3:-}"

  local current="${!key:-}"
  local port="${current:-$preferred}"
  local tries=0

  while [ "$tries" -lt 50 ]; do
    if port_available "$port" && ! port_reserved "$port"; then
      export "$key=$port"
      set_env_kv "$key" "$port"
      reserve_port "$port"
      return 0
    fi
    port=$((port + 1))
    tries=$((tries + 1))
  done

  echo "Port range busy for ${label}, selecting a random free port..."
  for _ in $(seq 1 50); do
    port="$(random_free_port)"
    if port_available "$port" && ! port_reserved "$port"; then
      export "$key=$port"
      set_env_kv "$key" "$port"
      reserve_port "$port"
      return 0
    fi
  done

  echo "ERROR: Could not find a free port for ${label}." >&2
  exit 1
}

ensure_docker_running() {
  command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker CLI not found." >&2
    exit 1
  }

  docker info >/dev/null 2>&1 && return 0

  echo "Docker daemon not running. Starting Docker Desktop..."
  if [[ "${OSTYPE:-}" == darwin* ]] && command -v open >/dev/null 2>&1; then
    open -a Docker >/dev/null 2>&1 || true
  fi

  for _ in $(seq 1 180); do
    docker info >/dev/null 2>&1 && return 0
    sleep 1
  done

  echo "ERROR: Docker did not become ready within 3 minutes." >&2
  exit 1
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

WITH_EXTRAS=false
NO_PULL=false
NO_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --extras)
      WITH_EXTRAS=true
      ;;
    --no-pull) NO_PULL=true ;;
    --no-build) NO_BUILD=true ;;
  esac
done

if [ -f "${IMAGES_CACHE_PATH:-backups/images-cache.tar}" ]; then
  echo "Loading image cache: ${IMAGES_CACHE_PATH:-backups/images-cache.tar}"
  docker load -i "${IMAGES_CACHE_PATH:-backups/images-cache.tar}" >/dev/null
fi

ensure_docker_running

ensure_port_free GRAFANA_PORT "Grafana" 3000
ensure_port_free PROMETHEUS_PORT "Prometheus" 9090
ensure_port_free ALERTMANAGER_PORT "Alertmanager" 9093
ensure_port_free MAILPIT_UI_PORT "Mailpit" 8025
ensure_port_free MINIO_PORT "MinIO API" 9000
ensure_port_free MINIO_CONSOLE_PORT "MinIO Console" 9001
ensure_port_free DEMO_APP_PORT "Demo app" 8088

if [ "$NO_PULL" = false ]; then
  if [ "$WITH_EXTRAS" = true ]; then
    bash scripts/pull-images.sh --extras
  else
    bash scripts/pull-images.sh
  fi
fi

PROFILE_ARGS=""
[ "$WITH_EXTRAS" = true ] && PROFILE_ARGS="--profile extras"

BUILD_ARGS="--build"
[ "$NO_BUILD" = true ] && BUILD_ARGS="--no-build"

PULL_POLICY_ARGS=""
[ "$NO_PULL" = true ] && PULL_POLICY_ARGS="--pull never"

# shellcheck disable=SC2086
compose $PROFILE_ARGS up -d $BUILD_ARGS $PULL_POLICY_ARGS

echo
echo "Grafana:       http://localhost:${GRAFANA_PORT:-3000} (user: ${GRAFANA_ADMIN_USER:-admin})"
echo "Prometheus:    http://localhost:${PROMETHEUS_PORT:-9090}"
echo "Alertmanager:  http://localhost:${ALERTMANAGER_PORT:-9093}"
echo "Mailpit:       http://localhost:${MAILPIT_UI_PORT:-8025}"
echo "MinIO:         http://localhost:${MINIO_CONSOLE_PORT:-9001}"
echo "Demo app:      http://localhost:${DEMO_APP_PORT:-8088}"
