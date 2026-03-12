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

OUT="backups/images-cache.tar"
OPTS=()
if [ "${1:-}" != "" ] && [[ "${1:-}" != -* ]]; then
  OUT="$1"
  shift
fi
OPTS=("$@")

mkdir -p "$(dirname "$OUT")"

echo "Prefetching images..."
bash scripts/pull-images.sh "${OPTS[@]}"

echo "Saving image cache to $OUT ..."

# Keep in sync with pull-images.sh
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

for opt in "${OPTS[@]}"; do
  if [ "$opt" = "--extras" ]; then
    images+=("${CADVISOR_IMAGE:-ghcr.io/google/cadvisor:0.55.1}")
    break
  fi
done

docker save -o "$OUT" "${images[@]}"
echo "Done."
