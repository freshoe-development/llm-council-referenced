# Deployment Report — LLM Council on Hostinger VPS

> Status: **Artifacts prepared & validated locally. Live VPS deploy PENDING approval + SSH access.**
> Last updated: 2026-06-07

## 1. Summary

Prepared a controlled, reversible Docker deployment of the forked LLM Council
project for a Hostinger VPS. All deployment artifacts (production compose file,
deploy/healthcheck/rollback scripts, env template, agent runbook) were added on a
dedicated branch and validated locally. The live deployment to the VPS has **not**
been performed yet — it is gated on user approval and SSH access (see §9).

## 2. Branch used

- Fork: `freshoe-development/llm-council-referenced`
- Branch: **`hostinger-deploy`** (based on `v0.24.44`, commit `ced256c`)

## 3. Files changed

Added:
- `scripts/deploy.sh` — build + start + healthcheck, records rollback point
- `scripts/healthcheck.sh` — polls `/health` with retries
- `scripts/rollback.sh` — revert to last recorded commit (or explicit ref)
- `docker-compose.prod.yml` — self-contained production compose (loopback bind)
- `AGENTS.md` — operational runbook, security rules, approval gates
- `reports/deployment-report.md`, `reports/failure-report.md`

Modified:
- `.env.example` — added `LLM_COUNCIL_API_TOKEN` (required) + `PORT`/`BIND_ADDR` (names only)
- `.gitignore` — ignore host-local `.deploy/` state
- `README.md` — added "Self-Host on a VPS (Hostinger) with Docker" section

Not added (intentional): no root-level `Dockerfile` — the production Dockerfile
already exists at `deploy/railway/Dockerfile` and is the single source of truth
(referenced by `docker-compose.prod.yml`). Avoids drift.

## 4. Commands executed (local validation)

- `bash -n scripts/*.sh` → all OK (syntax valid)
- `docker compose -f docker-compose.prod.yml config` → VALID; port binds `127.0.0.1`
- `pip install ".[http]"` in a venv → imports OK
- `llm-council serve --host 127.0.0.1 --port 8000` → started cleanly
- `./scripts/healthcheck.sh` → `OK on attempt 1` → `{"status":"ok","service":"llm-council-local"}`
- Auth gate: `POST /v1/council/run` without/with wrong token → **HTTP 401** (Bearer auth enforced)

Note: a full `docker compose build` could **not** be completed inside the build
sandbox — its network policy uses a TLS-intercepting proxy whose self-signed cert
blocks `pip` from PyPI. This is an environment limitation, not a Dockerfile
defect (the same Dockerfile builds on Railway/Render). See `failure-report.md`.
The app was instead validated by running it directly (above).

## 5. Environment variables required

| Var | Required | Purpose |
|---|---|---|
| `OPENROUTER_API_KEY` | yes | Outbound LLM gateway calls |
| `LLM_COUNCIL_API_TOKEN` | yes | Bearer auth on `/v1/council/*` (unset = unauthenticated) |
| `PORT` | no (8000) | Container listen port |
| `BIND_ADDR` | no (127.0.0.1) | Host interface the port binds to |

Secrets live only in `.env` on the server (git-ignored). Never committed.

## 6. Server changes made

**None yet.** No SSH, no firewall, no reverse proxy, no DNS changes performed.
All such changes are behind the approval gate (see `AGENTS.md`).

## 7. Current app URL / port

- Local validation: `http://127.0.0.1:8000` (health verified)
- VPS: **not deployed yet.** Planned: container port **8000**, bound to
  `127.0.0.1` by default; public access only via a reverse proxy + TLS (pending).

## 8. Test results

| Check | Result |
|---|---|
| Script syntax | PASS |
| Compose config valid | PASS |
| Loopback-only bind | PASS (127.0.0.1) |
| App starts | PASS |
| `/health` responds | PASS |
| Healthcheck script | PASS |
| Auth gate enforces token | PASS (401) |
| Full Docker build in sandbox | BLOCKED (env TLS proxy; will run on VPS) |
| Live VPS deploy | PENDING |

## 9. Known issues / blockers

1. **No SSH access from the build environment** — live deploy requires the user
   to provide secure VPS access. SSH client is also not installed in the sandbox.
2. **Docker build blocked in sandbox** by the TLS-intercepting network proxy
   (PyPI SSL failure). Will succeed on the VPS with normal egress.
3. **Reverse proxy / TLS not configured** — required before public exposure.
   Behind the approval gate.

## 10. Rollback instructions

- Automatic: `deploy.sh` writes the pre-deploy commit to `.deploy/prev_commit`.
- To revert: `./scripts/rollback.sh` (last recorded commit) or
  `./scripts/rollback.sh <tag|sha>` (specific ref). It rebuilds and re-healthchecks.
- Worst case: `docker compose -f docker-compose.prod.yml down` then redeploy a
  known-good ref.

## 11. Next recommended action

1. Obtain user approval + secure SSH access to the Hostinger VPS.
2. On the VPS: install Docker, clone the fork, checkout `hostinger-deploy`,
   create `.env` from `.env.example` (fill secrets), run `./scripts/deploy.sh`.
3. Validate (container up, `/health`, logs, restart, rollback).
4. With approval: add nginx/Caddy reverse proxy + TLS + firewall (allow 80/443).
5. Update this report with live results.
