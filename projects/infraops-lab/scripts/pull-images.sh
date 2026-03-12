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

WITH_EXTRAS=false
for arg in "$@"; do
  case "$arg" in
    --extras) WITH_EXTRAS=true ;;
  esac
done

image_present() {
  docker image inspect "$1" >/dev/null 2>&1
}

pull_with_retry() {
  local image="$1"
  local attempts="${PULL_ATTEMPTS:-6}"
  local delay="${PULL_DELAY_SECONDS:-2}"
  local i=1

  while [ "$i" -le "$attempts" ]; do
    echo "Pulling $image (attempt $i/$attempts)..."
    if docker pull "$image"; then
      return 0
    fi
    echo "Pull failed: $image"
    echo "Retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
    i=$((i + 1))
  done

  echo "ERROR: Could not pull $image after $attempts attempts."
  echo "If you see TLS handshake timeouts, your network/proxy/VPN is blocking registries."
  echo "Workaround: switch network (hotspot), or preload an image cache with scripts/cache-images.sh and rerun."
  return 1
}

images=(
  "${PYTHON_IMAGE:-python:3.12-slim}"
  "${PROMETHEUS_IMAGE:-prom/prometheus:v2.52.0}"
  "${ALERTMANAGER_IMAGE:-prom/alertmanager:v0.27.0}"
  "${GRAFANA_IMAGE:-grafana/grafana:11.1.0}"
  "${LOKI_IMAGE:-grafana/loki:3.1.1}"
  "${VECTOR_IMAGE:-timberio/vector:0.41.1-alpine}"
  "${BLACKBOX_IMAGE:-prom/blackbox-exporter:v0.25.0}"
  "${MAILPIT_IMAGE:-axllent/mailpit:v1.21}"
  "${MINIO_IMAGE:-minio/minio:RELEASE.2025-01-20T14-49-07Z}"
  "${MINIO_MC_IMAGE:-minio/mc:RELEASE.2025-01-17T23-25-50Z}"
  "${LOADGEN_IMAGE:-curlimages/curl:8.10.1}"
  "${RESTIC_IMAGE:-restic/restic:0.17.1}"
)

if [ "$WITH_EXTRAS" = true ]; then
  images+=("${CADVISOR_IMAGE:-ghcr.io/google/cadvisor:0.55.1}")
fi

for img in "${images[@]}"; do
  if image_present "$img"; then
    echo "Already present: $img"
    continue
  fi
  pull_with_retry "$img"
done
