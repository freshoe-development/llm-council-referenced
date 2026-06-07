# Deployment Report — LLM Council on Hostinger VPS

> Status: **DEPLOYED on VPS — app running, local healthcheck OK. Exposure is
> INSECURE (direct HTTP on :8000, no TLS) — hardening pending.**
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

Deploy executed on the VPS by the Hostinger agent (Kodee), not from this sandbox.
- Container built and started from `hostinger-deploy` @ `bdd7977`.
- Port **8000 opened directly** to the public internet (`BIND_ADDR=0.0.0.0` style),
  **no reverse proxy, no TLS**. This was not the recommended default and is a
  security gap (see §9).
- No DNS change (uses the provider hostname `srv1357811.hstgr.cloud`).

## 7. Current app URL / port

- Live: **http://srv1357811.hstgr.cloud:8000** (plain HTTP, port 8000).
- Health path: `/health`. Protected API: `/v1/council/run` (Bearer token).
- Not independently reachable from the build sandbox (outbound :8000 blocked);
  health confirmed via on-server `healthcheck.sh` = OK (operator-reported).

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
| Full Docker build in sandbox | BLOCKED (env TLS proxy) |
| Live VPS build (after fix) | PASS (operator-reported) |
| Live VPS deploy + healthcheck | PASS (operator-reported, `bdd7977`) |
| External reachability from sandbox | N/A (outbound :8000 blocked) |
| TLS / secure exposure | FAIL — plain HTTP on :8000 |

## 9. Known issues / blockers

1. **INSECURE EXPOSURE (high):** API served over plain **HTTP on :8000** with no
   TLS. `LLM_COUNCIL_API_TOKEN` and all request/response bodies travel in
   cleartext and are interceptable. Port is open to the whole internet.
   → Fix: reverse proxy (Caddy/nginx) + Let's Encrypt TLS, firewall to 80/443,
   rebind app to `127.0.0.1`.
2. **Leaked OpenRouter key (high):** the key was pasted into chat/screenshot
   during setup → must be **rotated** at openrouter.ai and updated in `.env`.
3. **No independent external verification** from the sandbox (outbound :8000 and
   :22 blocked by network policy). Live health is operator-reported.
4. Build regression (VERSION arg) — fixed in `bdd7977`.

## 10. Rollback instructions

- Automatic: `deploy.sh` writes the pre-deploy commit to `.deploy/prev_commit`.
- To revert: `./scripts/rollback.sh` (last recorded commit) or
  `./scripts/rollback.sh <tag|sha>` (specific ref). It rebuilds and re-healthchecks.
- Worst case: `docker compose -f docker-compose.prod.yml down` then redeploy a
  known-good ref.

## 11. Next recommended action

1. **Secure the exposure** (highest priority): put Caddy/nginx + TLS in front,
   rebind the app to `127.0.0.1`, firewall to allow only 80/443.
2. **Rotate** the leaked OpenRouter key; update `.env`; redeploy.
3. Re-test `/health` over HTTPS and the auth gate.
4. Confirm restart persistence and the `rollback.sh` path on the VPS.
