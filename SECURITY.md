# Security Policy

## Reporting a Vulnerability

Please **do not** open public GitHub issues for security vulnerabilities.

Email **cmlanche@qq.com** with subject `ShrimpSend Security` and include:

- Affected component (backend, web, Flutter, HarmonyOS, infrastructure)
- Steps to reproduce
- Impact assessment
- Suggested fix (if any)

We aim to acknowledge reports within **72 hours** and will coordinate disclosure after a fix is available.

## Supported Versions

Security fixes are applied to the latest release on the default branch. Self-hosted deployments should pull updates promptly.

## Credential Hygiene

- Never commit API keys, passwords, or production YAML/JSON to the public repository.
- Use the private `shrimpsend-ops` repo (`github.com/shrimpsend/ops`) and gitignored local files (see [ops/README.md](ops/README.md)).
- Rotate credentials that were ever committed to Git before open-sourcing.
