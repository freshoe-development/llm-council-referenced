# Failure Report — LLM Council Hostinger Deployment

Chronological log of failures, their cause, and resolution. Append new entries
at the top.

---

## 2026-06-07 — VPS Docker build failed at `pip install` (invalid version)

- **What happened:** On the Hostinger VPS, `./scripts/deploy.sh` failed during
  the image build at `Dockerfile:26` (`RUN pip install --no-cache-dir ".[http]"`,
  exit code 1). No container started; `healthcheck.sh` then failed 10/10 and
  `docker compose ps` was empty.
- **Cause:** Regression introduced in the first deploy commit. `deploy.sh` set
  `APP_VERSION=$(git describe --tags --always)` and passed it as the
  `VERSION` build-arg → `SETUPTOOLS_SCM_PRETEND_VERSION`. On the VPS clone this
  resolved to a bare commit hash (e.g. `5bc5542`), which is not a valid PEP 440
  version, so hatch-vcs/hatchling aborted the package build. Independent of
  network. (NB: this was NOT a missing-secret issue — the API key is only needed
  at runtime, after a successful build.)
- **Impact:** Deploy could not produce an image on the VPS.
- **Resolution:** Removed the `VERSION` build-arg override from
  `docker-compose.prod.yml` and the `APP_VERSION`/`git describe` lines from
  `deploy.sh` and `rollback.sh`, restoring the Dockerfile's known-good default
  (`0.0.0.dev0`). Re-validated: compose config valid, scripts syntax OK.
- **Status:** Fixed on `hostinger-deploy`. Re-pull + re-run required on the VPS.

---

## 2026-06-07 — Docker build blocked in build sandbox (PyPI SSL)

- **What happened:** `docker compose -f docker-compose.prod.yml build` failed at
  `RUN pip install --no-cache-dir ".[http]"` with
  `SSL: CERTIFICATE_VERIFY_FAILED ... self-signed certificate in certificate chain`
  when reaching `pypi.org`.
- **Cause:** The remote build environment's network policy routes egress through
  a TLS-intercepting proxy presenting a self-signed certificate. `pip` inside the
  Docker build cannot verify it. This is an **environment limitation**, not a
  defect in the Dockerfile (the same `deploy/railway/Dockerfile` builds cleanly on
  Railway/Render where egress is normal).
- **Impact:** Could not produce the final image inside the sandbox.
- **Resolution / workaround:** Validated the application without Docker — created a
  venv (`pip install ".[http]"` with trusted hosts), ran `llm-council serve`, and
  confirmed `/health` returns `{"status":"ok"}`, the healthcheck script passes, and
  the Bearer auth gate returns 401. The full container build will run on the VPS,
  which has normal network egress.
- **Status:** Resolved (deferred to VPS). No code change required.

---

## Template for future entries

## YYYY-MM-DD — <short title>

- **What happened:**
- **Cause:**
- **Impact:**
- **Resolution / workaround:**
- **Status:**
