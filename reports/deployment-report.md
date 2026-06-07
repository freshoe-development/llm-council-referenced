# Deployment Report — LLM Council on Hostinger VPS

> Status: **DEPLOYED + SECURED + PUBLISHED. App bound to `127.0.0.1:8000`
> (loopback), healthy. Public HTTPS via Caddy + Let's Encrypt at
> `https://council.72-61-193-40.nip.io`; `/v1/council/*` gated by Bearer auth.
> Verified externally + on-box 2026-06-07. See §12.**
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

## 12. Hardening + HTTPS publish (2026-06-07, verified live)

Done directly on the VPS (`srv1357811` / `72.61.193.40`) and verified both
externally and on-box. The host is **shared with Hermes production**, so all
changes were additive and non-disruptive.

### Verified pre-existing state (read-only, on-box)
- `llm-council` container bound to `127.0.0.1:8000` (loopback, via docker-proxy),
  `Up (healthy)`. The earlier "open on `0.0.0.0:8000`" exposure no longer existed;
  external `:8000` = CLOSED (raw TCP). On-box `/health` = `{"status":"ok"}`.
- Caddy (systemd, active) already terminated TLS on `:80`/`:443` for three Hermes
  sites (`72-61-193-40.nip.io`, `dashboard.*`, `office.*`).

### Change made (additive, reversible)
- Backed up `/etc/caddy/Caddyfile` → `Caddyfile.bak`.
- Added one vhost (see `deploy/caddy/council.Caddyfile`):

      council.72-61-193-40.nip.io {
          encode gzip
          reverse_proxy 127.0.0.1:8000
      }

- `caddy validate` → VALID; `systemctl reload caddy` (graceful, no downtime).
- No firewall change required: `80`/`443` already open; `8000` stays loopback-only.

### External verification (from operator machine)
| Check | Result |
|---|---|
| `GET https://council.72-61-193-40.nip.io/health` | **200** `{"status":"ok","service":"llm-council-local"}` |
| TLS certificate | **Let's Encrypt**, `CN=council.72-61-193-40.nip.io`, valid 2026-06-07 → 2026-09-05 |
| `POST /v1/council/run` (no token) | **401** — Bearer auth enforced |
| `dashboard.*` / `office.*` (Hermes) | 401 (basicauth) — unaffected |
| Hermes root `72-61-193-40.nip.io` (→ `:8642`) | **502 — PRE-EXISTING** (`:8642` not listening before/after; unrelated to this change) |

### Public endpoint for the cloud session
- Base URL: `https://council.72-61-193-40.nip.io`
- Open: `GET /health`
- Authenticated: `POST /v1/council/run`, `GET /v1/council/stream`
  Header: `Authorization: Bearer <LLM_COUNCIL_API_TOKEN>` (token in server `.env`,
  never committed).

### Notes
- OpenRouter key rotation: **not performed** (operator decision — one-time
  experiment).
- Access: operator added the agent SSH public key (`work@freshoe`) to
  `/root/.ssh/authorized_keys` via the Hostinger Browser Terminal. Two keys were
  registered in the Hostinger account during setup
  (`claude-work-freshoe`, `saif-accounts-freshoe`) — these only apply on a rebuild.
- Flagged (out of scope): Hermes chat root (`:8642`) returns 502 (gateway not
  listening). Not caused by this work.
