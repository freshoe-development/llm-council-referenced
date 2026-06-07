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

Protected requests need a secret token named `LLM_COUNCIL_API_TOKEN`. It is
stored in the `.env` file on the server — you do not memorize it.

Tell your local Claude session, once per session:

> Read the token `LLM_COUNCIL_API_TOKEN` from `~/llm-council-referenced/.env`
> on the server, and use it on every request to the council tool.

The token is fixed — fetched once, reused on every request. A new session means
you give this instruction once more.

## Step 2 — Ask a question (every time)

Then simply say:

> Send this question to the council tool: *\<your question\>*

You only provide the question; the token is attached automatically.

---

## Optional — Manual run (without Claude)

If you prefer a direct call from a terminal:

```bash
curl -X POST https://council.72-61-193-40.nip.io/v1/council/run \
  -H "Authorization: Bearer <the token>" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"<your question>"}'
```

> Note: `<the token>` is the value of `LLM_COUNCIL_API_TOKEN` from the server's
> `.env`. Never paste the token into chat or commit it to git.
