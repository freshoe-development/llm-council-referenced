# How to Use the Council Tool

A short, non-technical guide for using the deployed LLM Council instance.

**Live URL:** `https://council.72-61-193-40.nip.io`

The tool is a service (not a web page you click). You send it a question and it
returns a deliberated answer. Protected requests require a token.

---

## Quick health check (no token)

Open this in a browser:

```
https://council.72-61-193-40.nip.io/health
```

It should return:

```json
{"status":"ok","service":"llm-council-local"}
```

---

## Step 1 — The token (one time)

Protected requests need a secret token (`LLM_COUNCIL_API_TOKEN`), stored in the
server's `.env`. Retrieve it **yourself** over SSH and keep it somewhere safe (a
password manager, or a shell environment variable) — avoid asking a chat agent
to read secrets, since they can leak into logs or transcripts.

```bash
ssh <user>@srv1357811.hstgr.cloud \
  'grep -E "^LLM_COUNCIL_API_TOKEN=" ~/llm-council-referenced/.env'
# copy the value after the '=' and keep it locally, e.g.:
export COUNCIL_TOKEN='paste-the-value-here'
```

The token is fixed — capture it once and reuse it on every request.

## Step 2 — Ask a question (every time)

Then simply say:

> Send this question to the council tool: *\<your question\>*

You only provide the question; the token is attached automatically.

---

## Optional — Manual run (without Claude)

If you prefer a direct call from a terminal:

```bash
curl -X POST https://council.72-61-193-40.nip.io/v1/council/run \
  -H "Authorization: Bearer $COUNCIL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"<your question>"}'
```

> Note: `$COUNCIL_TOKEN` is the value of `LLM_COUNCIL_API_TOKEN` you captured
> above. Never paste the token into chat or commit it to git.
