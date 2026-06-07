# AGENTS.md — Operating Guide for Automated Agents

This file tells AI agents (and humans driving them) how to work on **deployment**
of this fork safely. For application architecture, read `CLAUDE.md`. For release
process, read the "Release Workflow" section of `CLAUDE.md`.

## Scope of this fork's deployment work

This fork is deployed as a small, controlled Docker service on a single VPS
(Hostinger). Keep changes **minimal, traceable, and reversible**. This is a
deployment project, not a refactor — do not restructure the application.

## Repositories & branches

| Purpose | Repo | Branch |
|---|---|---|
| Application code (this fork) | `freshoe-development/llm-council-referenced` | `hostinger-deploy` |
| Operational notes, reports, decision logs | `freshoe-development/claude-environment` | (deploy branch) |

- Develop deployment changes on **`hostinger-deploy`**.
- Mirror reports into both the fork's `reports/` and the `claude-environment` repo.
- Do **not** create a third repository.

## Hard security rules

1. **Never commit secrets** — no API keys, tokens, passwords, or `.env` files.
   `.env` and `.deploy/` are git-ignored; keep it that way.
2. `.env.example` documents **variable names only**, never real values.
3. Do not hardcode credentials anywhere in code, compose files, or scripts.
4. Do not open ports beyond what is needed. The app uses **one port: 8000**.
5. The production compose binds to **127.0.0.1 by default** (loopback). Public
   exposure requires a reverse proxy + firewall — see the approval gate below.

## Approval gate — STOP and ask before any risky action

Pause and request explicit approval before:

- deleting files, or overwriting existing files on the server;
- changing firewall rules (UFW/iptables) or opening new ports;
- changing production environment variables;
- modifying DNS, a reverse proxy, or TLS configuration;
- restarting unrelated services on the host;
- committing large structural changes.

## Deployment model

Docker Compose on the VPS using `docker-compose.prod.yml`:

```bash
# one-time, on the server:
git clone <fork-url> && cd llm-council-referenced
git checkout hostinger-deploy
cp .env.example .env          # then fill in real secrets — never commit this

# deploy / upgrade:
./scripts/deploy.sh           # records rollback point, builds, starts, healthchecks

# verify:
./scripts/healthcheck.sh      # polls http://127.0.0.1:8000/health

# revert:
./scripts/rollback.sh         # back to the last recorded commit
./scripts/rollback.sh v0.24.43  # or to a specific ref
```

### What `deploy.sh` guarantees
- Refuses to run without a populated `.env` containing `OPENROUTER_API_KEY`
  and `LLM_COUNCIL_API_TOKEN`.
- Writes the current commit to `.deploy/prev_commit` before changing anything.
- Blocks on the healthcheck and fails loudly (pointing at `rollback.sh`).

## Required environment variables

| Var | Required | Purpose |
|---|---|---|
| `OPENROUTER_API_KEY` | yes | Outbound LLM gateway calls (OpenRouter) |
| `LLM_COUNCIL_API_TOKEN` | yes | Bearer auth on `/v1/council/*`. Unset = endpoints are unauthenticated. |
| `PORT` | no (default 8000) | Listen port inside the container |
| `BIND_ADDR` | no (default 127.0.0.1) | Host interface the port binds to |

See `.env.example` for the full optional set.

## Validation checklist (run before declaring success)

1. Container is running (`docker compose -f docker-compose.prod.yml ps`).
2. App responds on the expected port (`./scripts/healthcheck.sh`).
3. Healthcheck passes (`GET /health` → `{"status":"ok"}`).
4. Logs show no critical errors (`docker compose -f docker-compose.prod.yml logs`).
5. Required env vars detected (deploy.sh pre-flight passed).
6. Restart behaves (`restart: always`; survives `docker restart`).
7. Rollback path documented and tested.

## Record-keeping

After every major step, record in `reports/` (and `claude-environment`):
what changed · why · evidence · command-output summary · next step.
