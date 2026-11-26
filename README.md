<p align="center">
  <img src="public/icon.svg" width="96" height="96" alt="Foresight">
</p>

# Foresight

[![CI](https://github.com/mrecek/foresight/actions/workflows/ci.yml/badge.svg)](https://github.com/mrecek/foresight/actions/workflows/ci.yml)

Foresight is a self-hosted cash-flow forecaster. It uses account balances and
recurring income, expenses, and transfers to project up to 24 months ahead
and show when money may run short.

Foresight runs on Rails and SQLite, with separate web and background jobs
containers that share one persistent volume. The image supports Linux AMD64
and ARM64.

## Quick start

```bash
git clone https://github.com/mrecek/foresight.git
cd foresight
docker compose up -d
```

Open [localhost:3000](http://localhost:3000) to complete setup. If you already
run Foresight, check the [upgrade procedure](.agents/skills/foresight-dev/references/installation.md#upgrade)
before updating.

- [Deployment and configuration](docs/deployment.md) covers the container and
  storage requirements, Kubernetes, and single sign-on.
- [Contributing](CONTRIBUTING.md) covers development and validation.
- [License](LICENSE) is MIT.
