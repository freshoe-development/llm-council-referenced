#!/usr/bin/env bash
#
# scripts/deploy.sh — Deploy LLM Council on a single-host Docker server
# (e.g. a Hostinger VPS).
#
# Safe by design:
#   * Refuses to run without a populated .env (secrets never live in git).
#   * Records the current commit BEFORE deploying so rollback.sh can revert.
#   * Builds, starts, then blocks on a healthcheck — a failed deploy is loud.
#
# Usage (on the server, inside the repo checkout):
#   cp .env.example .env        # fill in real secrets, then:
#   ./scripts/deploy.sh
#
# Override behaviour with env vars:
#   DEPLOY_BRANCH (default: hostinger-deploy)
#   PORT          (default: 8000)        host port the app listens on
#   BIND_ADDR     (default: 127.0.0.1)   loopback-only unless you set 0.0.0.0
#
set -euo pipefail

APP_DIR="${APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEPLOY_BRANCH="${DEPLOY_BRANCH:-hostinger-deploy}"
PORT="${PORT:-8000}"
STATE_DIR="${APP_DIR}/.deploy"
PREV_COMMIT_FILE="${STATE_DIR}/prev_commit"
COMPOSE=(docker compose -f docker-compose.prod.yml)

log()  { printf '[deploy] %s\n' "$*"; }
die()  { printf '[deploy][ERROR] %s\n' "$*" >&2; exit 1; }

cd "$APP_DIR"

# --- Pre-flight -------------------------------------------------------------
command -v docker >/dev/null 2>&1 || die "docker is not installed on this host."
docker compose version >/dev/null 2>&1 || die "the 'docker compose' plugin is not available."
[ -f .env ] || die ".env is missing. Copy .env.example to .env and fill in secrets (never commit it)."

# Verify required variables are present (we check names + that they are non-empty;
# the actual values stay inside .env and are never printed).
for var in OPENROUTER_API_KEY LLM_COUNCIL_API_TOKEN; do
  if ! grep -qE "^${var}=.+" .env; then
    die "Required variable ${var} is missing or empty in .env"
  fi
done
# Reject the placeholder values shipped in .env.example so a half-configured
# .env fails fast with a clear message instead of later at runtime.
if grep -qE "^OPENROUTER_API_KEY=your-openrouter-api-key-here$" .env \
   || grep -qE "^LLM_COUNCIL_API_TOKEN=your-strong-random-token-here$" .env; then
  die ".env still contains placeholder values from .env.example — set real secrets."
fi
log "Pre-flight OK (.env present, required variables detected)."

mkdir -p "$STATE_DIR"

# --- Record current state for rollback -------------------------------------
CURRENT_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo "$CURRENT_COMMIT" > "$PREV_COMMIT_FILE"
log "Recorded current commit for rollback: ${CURRENT_COMMIT}"

# --- Update code ------------------------------------------------------------
log "Fetching origin/${DEPLOY_BRANCH} ..."
git fetch --tags origin "$DEPLOY_BRANCH"
git checkout "$DEPLOY_BRANCH"
# Only fast-forward when on a branch; deploying a tag or commit SHA leaves a
# detached HEAD where 'git pull' is meaningless and would fail.
if git symbolic-ref -q HEAD >/dev/null; then
  git pull --ff-only origin "$DEPLOY_BRANCH"
else
  log "Detached HEAD (tag or SHA) — skipping git pull."
fi
NEW_COMMIT="$(git rev-parse HEAD)"
log "Deploying commit: ${NEW_COMMIT}"

# --- Build & start ----------------------------------------------------------
log "Building image ..."
"${COMPOSE[@]}" build
log "Starting container(s) ..."
"${COMPOSE[@]}" up -d

# --- Validate ---------------------------------------------------------------
log "Waiting for health on 127.0.0.1:${PORT}/health ..."
if PORT="$PORT" "${APP_DIR}/scripts/healthcheck.sh"; then
  log "Healthcheck passed. Deploy SUCCEEDED at ${NEW_COMMIT}."
  "${COMPOSE[@]}" ps
else
  die "Healthcheck FAILED. The previous commit was ${CURRENT_COMMIT}. Run: ./scripts/rollback.sh"
fi
