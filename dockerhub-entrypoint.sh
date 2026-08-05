#!/usr/bin/env bash
set -euo pipefail

export NON_INTERACTIVE="${NON_INTERACTIVE:-1}"
export EXISTING_PATH_MODE="${EXISTING_PATH_MODE:-overwrite}"

# Compatibility shim: the scaffold script expects `docker-compose`.
if ! command -v docker-compose >/dev/null 2>&1; then
  cat >/usr/local/bin/docker-compose <<'EOF'
#!/usr/bin/env sh
exec docker compose "$@"
EOF
  chmod +x /usr/local/bin/docker-compose
fi

mkdir -p /workspace
cd /workspace

if [ "$#" -eq 0 ] && [ -n "${PROJECT_NAME:-}" ]; then
  set -- "$PROJECT_NAME"
fi

exec bash /usr/local/bin/docker_pyNext_v3 "$@"
