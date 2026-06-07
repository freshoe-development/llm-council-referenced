# HANDOFF — تأمين نشر LLM Council على Hostinger VPS

الهدف المتبقي: تأمين تطبيق منشور وشغّال (HTTPS + جدار حماية + تدوير مفتاح مكشوف).
مهمة صغيرة محكومة: تغييرات أقل ما يمكن، قابلة للتراجع. لا refactor.

## الحالة
- التطبيق منشور ويعمل، `healthcheck` = OK.
- URL: `http://srv1357811.hstgr.cloud:8000` (HTTP مباشر، بدون TLS — غير آمن)
- المنفذ 8000 مفتوح للإنترنت مباشرة.

## المستودعات (لا تنشئ مستودعًا ثالثًا)
- الكود (fork): `freshoe-development/llm-council-referenced` | branch: `hostinger-deploy` | منشور @ `bdd7977`
- التقارير: `freshoe-development/claude-environment` | branch: `claude/sweet-archimedes-CjvmY` | folder: `reports/`

## على الخادم
- المسار: `~/llm-council-referenced`
- ملفات: `docker-compose.prod.yml`، `scripts/deploy.sh`، `scripts/healthcheck.sh`، `scripts/rollback.sh`
- نقطة rollback: `.deploy/prev_commit` = `bdd7977`
- `.env` موجود على الخادم (يحوي المفاتيح، لا يُرفع لـ git)

## المتبقي (نفّذ عبر SSH من جهاز Saif — Windows-MCP / Desktop Commander)
1. تأمين العرض: أضف reverse proxy (Caddy أسهل) + HTTPS تلقائي على `srv1357811.hstgr.cloud`،
   أعد ربط التطبيق على `127.0.0.1` (`BIND_ADDR=127.0.0.1`)، افتح `80/443` فقط، اقفل 8000 خارجيًا.
2. دوّر مفتاح OpenRouter من openrouter.ai، حدّث `.env`، ثم:
   `./scripts/deploy.sh && ./scripts/healthcheck.sh`

## قواعد صارمة
- لا تكتب أي مفتاح/سر في git أو في الشات.
- أي تغيير firewall/proxy/منافذ: **نفّذ بشروط** — اشرح ثم نفّذ.
- لا تقبل تقرير إنجاز دون تحقق مباشر (افحص النتيجة بنفسك).
- بعد كل خطوة: حدّث `reports/deployment-report.md` في الـ fork وانسخه إلى `claude-environment`.

## الوصول
مفتاح SSH على جهاز Saif، الخادم `srv1357811.hstgr.cloud`.
ابدأ بقراءة `reports/` في المستودعين، ثم نفّذ البندين.
