#!/usr/bin/env bash
#
# scripts/rollback.sh — revert to the previously deployed commit (recorded by
# deploy.sh) and rebuild. Optionally pass an explicit git ref to roll back to.
#
# Usage:
#   ./scripts/rollback.sh                 # revert to the last recorded commit
#   ./scripts/rollback.sh v0.24.43        # revert to a specific tag/commit
#
set -euo pipefail

APP_DIR="${APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PORT="${PORT:-8000}"
STATE_DIR="${APP_DIR}/.deploy"
PREV_COMMIT_FILE="${STATE_DIR}/prev_commit"
COMPOSE=(docker compose -f docker-compose.prod.yml)

log() { printf '[rollback] %s\n' "$*"; }
die() { printf '[rollback][ERROR] %s\n' "$*" >&2; exit 1; }

cd "$APP_DIR"

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  [ -f "$PREV_COMMIT_FILE" ] || die "No previous commit recorded and no target ref given."
  TARGET="$(cat "$PREV_COMMIT_FILE")"
fi
[ "$TARGET" != "unknown" ] || die "Recorded previous commit is 'unknown'; pass an explicit ref."

log "Rolling back to: ${TARGET}"
git fetch --tags origin || true
git checkout "$TARGET"

export APP_VERSION="$(git describe --tags --always 2>/dev/null || echo 0.0.0.dev0)"
log "Rebuilding image (${APP_VERSION}) ..."
"${COMPOSE[@]}" build
"${COMPOSE[@]}" up -d

log "Verifying health ..."
if PORT="$PORT" "${APP_DIR}/scripts/healthcheck.sh"; then
  log "Rollback to ${TARGET} SUCCEEDED and is healthy."
  "${COMPOSE[@]}" ps
else
  die "Rollback to ${TARGET} did NOT become healthy. Manual intervention required."
fi
