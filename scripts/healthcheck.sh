#!/usr/bin/env bash
#
# scripts/healthcheck.sh — poll the LLM Council /health endpoint until it is
# ready (or give up). Exit 0 means healthy, non-zero means unhealthy.
#
# Used by deploy.sh and rollback.sh, but also safe to run by hand:
#   ./scripts/healthcheck.sh
#
# Override with env vars:
#   HEALTH_HOST   (default: 127.0.0.1)
#   PORT          (default: 8000)
#   HEALTH_PATH   (default: /health)
#   HEALTH_RETRIES(default: 10)
#   HEALTH_SLEEP  (default: 3 seconds between attempts)
#
set -euo pipefail

HEALTH_HOST="${HEALTH_HOST:-127.0.0.1}"
PORT="${PORT:-8000}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-10}"
HEALTH_SLEEP="${HEALTH_SLEEP:-3}"
URL="http://${HEALTH_HOST}:${PORT}${HEALTH_PATH}"

for attempt in $(seq 1 "$HEALTH_RETRIES"); do
  if body="$(curl -fsS --max-time 5 "$URL" 2>/dev/null)"; then
    echo "[healthcheck] OK on attempt ${attempt}: ${URL}"
    echo "[healthcheck] response: ${body}"
    exit 0
  fi
  echo "[healthcheck] attempt ${attempt}/${HEALTH_RETRIES} failed; retrying in ${HEALTH_SLEEP}s ..."
  sleep "$HEALTH_SLEEP"
done

echo "[healthcheck] FAILED after ${HEALTH_RETRIES} attempts: ${URL}" >&2
exit 1
