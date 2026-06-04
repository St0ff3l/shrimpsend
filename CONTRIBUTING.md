# Contributing to ShrimpSend / 虾传

Thank you for your interest in contributing. This project is licensed under **AGPL-3.0-or-later**; by submitting a contribution you agree that your work will be licensed under the same terms.

## Before you start

1. Read [LICENSE](LICENSE), [LICENSE.zh-CN.md](LICENSE.zh-CN.md), and [TRADEMARK.md](TRADEMARK.md).
2. For self-hosting, see [docs/SELF_HOST.md](docs/SELF_HOST.md).
3. Search existing [Issues](https://github.com/shrimpsend/shrimpsend/issues) to avoid duplicate work.

## Developer Certificate of Origin (DCO)

We use the [Developer Certificate of Origin](DCO.md) (version 1.1). Every commit in a pull request must include a `Signed-off-by` line that matches the commit author:

```
Signed-off-by: Your Name <you@example.com>
```

Use `git commit -s` to add it automatically. By signing off, you certify the contribution terms in [DCO.md](DCO.md).

## Development setup

Clone the public repository:

```bash
git clone git@github.com:shrimpsend/shrimpsend.git
cd shrimpsend
```

**Maintainers** (with `ops/local/` from private [shrimpsend/ops](https://github.com/shrimpsend/ops)):

```bash
./scripts/deploy-local.sh
./scripts/start-dev.sh              # China logic
# ./scripts/start-dev.sh --overseas # ShrimpSend logic
```

**Contributors**:

```bash
./scripts/setup-local-config.sh
# Create MySQL database `ultrasend`, then:
./scripts/start-dev.sh
```

Stop: `./scripts/stop-dev.sh` · Logs: `scripts/logs/`

See [README.md](README.md) (English, default) and [docs/README.zh-CN.md](docs/README.zh-CN.md) (中文) for production deploy, Docker, and troubleshooting.

## Pull request guidelines

1. **One logical change per PR** — bug fix, feature, or docs; avoid mixing unrelated refactors.
2. **Describe the why** — link issues when applicable; include test/verification steps.
3. **Match existing style** — follow patterns in surrounding code; run formatters/linters for touched areas.
4. **No secrets** — never commit API keys, passwords, or production config; use `.env.example` and local ignored files.
5. **License & DCO** — you confirm you have the right to submit the code, license it under AGPL-3.0-or-later, and include `Signed-off-by` on every commit (see [DCO.md](DCO.md)).

### By area

| Area | Notes |
| --- | --- |
| `backend/` | Java 17, Spring Boot; `./gradlew test` when touching server logic |
| `web/` | Next.js; `npm run lint` in `web/` |
| `app/` | Flutter; `flutter analyze` in `app/` |
| `shared/protocol.md` | Protocol changes need client + server alignment |

## Issue reports

Include:

- Platform (iOS, Android, Windows, macOS, Linux, Web, HarmonyOS)
- Official vs self-hosted instance
- Steps to reproduce, expected vs actual behavior
- Logs or screenshots when helpful (redact tokens)

## Security

Do **not** open public issues for vulnerabilities. See [SECURITY.md](SECURITY.md).

## Commercial licensing

If your organization cannot comply with AGPL for internal modifications, see [LICENSE-Commercial.md](LICENSE-Commercial.md).

## Code of conduct

Be respectful and constructive. Harassment or spam will not be tolerated.
