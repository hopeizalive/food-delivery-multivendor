#!/usr/bin/env bash
# Shared helpers for scripts/build-setup/*.sh. Sourced, not executed directly.

REQUIRED_NODE_MAJOR=20

log()  { printf '\033[1;34m[build-setup]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[build-setup] warning:\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31m[build-setup] error:\033[0m %s\n' "$1" >&2; }

# Root of the repo, regardless of where a script is invoked from.
repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

check_node_version() {
  if ! command -v node >/dev/null 2>&1; then
    err "node not found on PATH. Install Node ${REQUIRED_NODE_MAJOR}.x first."
    return 1
  fi
  local major
  major="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "$major" != "$REQUIRED_NODE_MAJOR" ]; then
    warn "node is v$(node -p process.version), apps pin v${REQUIRED_NODE_MAJOR}.x (.nvmrc). Continuing anyway."
  fi
}

# install_deps <app-dir>
install_deps() {
  local dir="$1"
  if [ -f "$dir/package-lock.json" ]; then
    (cd "$dir" && npm ci --legacy-peer-deps)
  else
    (cd "$dir" && npm install --legacy-peer-deps)
  fi
}

# codespaces_forwarded_url <port> — echoes this Codespace's public forwarded
# URL for <port>, or nothing if not running in Codespaces.
codespaces_forwarded_url() {
  local port="$1"
  if [ "${CODESPACES:-}" = "true" ] && [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    printf 'https://%s-%s.%s' "$CODESPACE_NAME" "$port" "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"
  fi
}
