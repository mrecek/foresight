<p align="center">
  <img src="public/icon.svg" width="96" height="96" alt="Foresight">
</p>

# Foresight

[![CI](https://github.com/mrecek/foresight/actions/workflows/ci.yml/badge.svg)](https://github.com/mrecek/foresight/actions/workflows/ci.yml)

Foresight is a self-hosted cash-flow forecasting application. It turns current balances and recurring income, expenses, and transfers into a forward-looking view of your finances, so a future shortfall is visible before it becomes a problem.

It is a focused personal-finance tool rather than an accounting platform: simple to operate, private by default, and packaged as a multi-architecture container with no required external services.

## What it does

- Projects account balances up to 24 months ahead.
- Tracks checking, savings, credit-card, and other account balances.
- Models recurring income, expenses, and transfers.
- Reconciles projections against actual balances and transactions.
- Highlights low-balance risks before their expected date.
- Keeps financial data in an installation-owned SQLite database.

## Quick start

The included Compose configuration is the easiest supported deployment:

```bash
git clone https://github.com/mrecek/foresight.git
cd foresight
docker compose up -d
```

Open `http://localhost:3000` and complete the initial setup. Compose stores the databases and installation-specific session key in the `foresight_data` volume.

To run the same image without Compose:

```bash
docker run -d \
  --name foresight \
  --restart unless-stopped \
  -p 3000:8080 \
  -v foresight_data:/rails/storage \
  -e APP_TIME_ZONE=UTC \
  ghcr.io/mrecek/foresight:latest
```

The image supports `linux/amd64` and `linux/arm64`. `latest` follows the newest accepted release; use a published full commit-SHA tag when deployment policy requires an immutable version.

## Deployment contract

Foresight can run under Docker, Compose, Kubernetes, or another OCI-compatible platform. A deployment needs:

- one running application replica;
- persistent, writable storage mounted at `/rails/storage`;
- HTTP traffic sent to container port `8080`;
- an HTTP health probe against `/up`; and
- TLS terminated by a reverse proxy or ingress in front of the container.

The single-replica requirement matters: the primary database, cache, and job queue are SQLite files and require single-writer storage. The container runs as non-root user and group `1000:1000`; bind-mounted storage must be writable by that identity.

Background maintenance runs inside the web process by default. Advanced deployments may set `SOLID_QUEUE_IN_PUMA=false` and run exactly one `bin/jobs` process against the same persistent storage.

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `APP_TIME_ZONE` | Application dates, projections, and schedules; accepts IANA or Rails timezone names | `Pacific Time (US & Canada)` |
| `AUTH_USERNAME` | Override the database-stored login username | Database value |
| `AUTH_PASSWORD` | Override the database-stored login password | Database value |
| `SECRET_KEY_BASE` | Externally managed session-encryption key of at least 30 bytes | Generated per installation |
| `SECRET_KEY_BASE_FILE` | Path for the generated installation key | `/rails/storage/.secret_key_base` |
| `RAILS_LOG_LEVEL` | Application logging verbosity | `info` |
| `SOLID_QUEUE_IN_PUMA` | Run scheduled work in the web process | `true` |
| `THRUSTER_HTTP_PORT` | Container listener port | `8080` |

An unset `SECRET_KEY_BASE` is safe: first startup generates a cryptographically random key in persistent storage with private permissions. Supplying or changing an external key invalidates existing browser sessions. Startup fails when the configured key or generated-key file is unsafe, unreadable, or too short.

Invalid application timezones also fail startup instead of silently shifting financial dates.

## Backups

All durable application state lives under `/rails/storage`, but a live database file should not be copied directly. `bin/backup` uses SQLite's online backup API and packages the primary database with its checksum, schema version, integrity result, and material record counts.

```bash
docker exec foresight mkdir -p /rails/storage/backups
docker exec foresight bin/backup \
  --output /rails/storage/backups/foresight-backup.tar.gz
docker cp foresight:/rails/storage/backups/foresight-backup.tar.gz .
```

Keep multiple encrypted generations outside the application host and periodically test a restore. `bin/restore --help` describes the guarded restore path. Restore validates into a temporary database before publication, rejects newer unsupported schemas, and preserves an existing database when explicit replacement is requested.

The generated session key is deliberately excluded from backups. A restored installation creates or retains its own key, which signs out sessions copied from the source.

## Architecture

Foresight is a Ruby on Rails application using Hotwire, Turbo, Stimulus, and Tailwind for its server-rendered interface. Propshaft and Importmap keep the browser toolchain inside Rails, so production and local development do not require Node.js.

SQLite provides three isolated stores under the same persistent directory:

- the primary financial database;
- a disposable application cache; and
- the Solid Queue job database.

Financial mutations run through explicit command boundaries and database transactions. Linked transfers are treated as one two-sided financial operation; their invariants and conservative repair behavior are documented in [Transfer-pair invariants](docs/transfer-pair-invariants.md).

The production image uses Thruster in front of Puma, runs without root privileges, prepares pending database migrations at startup, and includes a built-in health check.

## Maintenance and security

Routine gem patch and minor updates are proposed by Dependabot and may merge only after the complete pull-request validation contract passes. Ruby patch releases update the local runtime declaration and digest-pinned container base together. GitHub Actions, Docker changes, major dependency versions, and Ruby minor or major upgrades remain under human review.

Scheduled security checks audit Ruby dependencies, browser imports, Rails application code, and the built production image. Release publication builds an unpromoted candidate, smoke-tests both supported architectures, verifies provenance, and only then promotes public tags.

Foresight is maintained primarily for the author's own use and shared in the hope that it is useful to other self-hosters. Bug reports are welcome; feature work is intentionally kept focused.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for supported development environments, setup, validation, and contribution expectations.

## License

Foresight is available under the [MIT License](LICENSE).
