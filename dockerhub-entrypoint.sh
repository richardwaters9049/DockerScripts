#!/usr/bin/env bash
set -euo pipefail

# Compatibility shim: the scaffold script expects `docker-compose`.
if ! command -v docker-compose >/dev/null 2>&1; then
  cat >/usr/local/bin/docker-compose <<'EOF'
#!/usr/bin/env sh
exec docker compose "$@"
EOF
  chmod +x /usr/local/bin/docker-compose
fi

exec bash /usr/local/bin/docker_pyNext_v3 "$@"
