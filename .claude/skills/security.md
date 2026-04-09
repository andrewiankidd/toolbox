---
name: security
description: Scan the codebase for hardcoded secrets, common vulnerabilities, and security anti-patterns
---

Scan the codebase for security issues and report findings. Do not auto-fix unless the user asks.

## What to look for

### Hardcoded secrets
- API keys, tokens, passwords in source code or config
- Connection strings with embedded credentials
- Private keys, certificates, PFX files checked in
- `.env` files or `appsettings.*.json` with real credentials committed
- Base64-encoded strings that decode to secrets

### Common vulnerabilities
- SQL string concatenation (SQL injection)
- Unsanitized user input in HTML output (XSS)
- Command injection via string-interpolated shell commands
- Path traversal — user input in file paths without sanitization
- Deserialization of untrusted data
- Insecure randomness (`Math.Random`, `Random()` for security purposes)
- Hardcoded cryptographic keys or IVs
- Disabled SSL/TLS verification
- Overly permissive CORS

### Dependency concerns
- Known vulnerable package versions (check against project files)
- Packages pulled from untrusted sources
- Pinned to very old major versions

### Auth/access
- Missing authorization checks on endpoints
- Default credentials in code or config
- Tokens/sessions that never expire
- Sensitive data in URL query parameters or logs

## Process

1. Identify the project type, language(s), and frameworks
2. Search for secrets using common patterns (grep for key, secret, password, token, apikey, connectionstring)
3. Check `.gitignore` — flag if `.env`, credential files, or key files are NOT ignored
4. Review code for vulnerability patterns relevant to the detected frameworks
5. Check dependency files for known issues

## Output format

Rate each finding:
- **Critical** — exploitable now (hardcoded secret, SQL injection)
- **High** — likely exploitable with some effort
- **Medium** — bad practice that could become exploitable
- **Low** — hygiene issue

For each finding:
- Severity, file path, line number
- What the issue is
- How it could be exploited
- Suggested fix

## Rules

- Don't flag example/placeholder values (e.g. `your-api-key-here`)
- Don't flag test fixtures with fake credentials
- Secrets in git history are still a finding — mention `git log` follow-up
- Do not make changes unless explicitly asked
