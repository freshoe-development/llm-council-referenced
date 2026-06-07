# Failure Report — LLM Council Hostinger Deployment

Chronological log of failures, their cause, and resolution. Append new entries
at the top.

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
