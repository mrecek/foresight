# Foresight

A personal cash flow projection app that helps you see your future account balances based on recurring income and expenses.

**Note:** This is a personal project I maintain for my own use, shared in case others find it useful. See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## Features

- 🔮 **Cash flow projection** - See projected balances up to 24 months ahead
- 📊 **Multi-account tracking** - Monitor checking, savings, and credit cards
- 🔄 **Recurring transactions** - Define flexible income and expense rules
- ⚠️ **Low balance warnings** - Get alerts when projections dip below safety thresholds
- 🐋 **Docker-first** - Designed for easy self-hosting

## Quick Start (Docker)

The easiest way to run Foresight is via Docker.

### Run with Docker CLI

```bash
docker run -d \
  --name foresight \
  -p 3000:8080 \
  -v foresight_data:/rails/storage \
  ghcr.io/mrecek/foresight:latest
```

Visit `http://localhost:3000` to set up your account.

### Run with Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  foresight:
    image: ghcr.io/mrecek/foresight:latest
    container_name: foresight
    restart: unless-stopped
    ports:
      - "3000:8080"
    volumes:
      - foresight_data:/rails/storage
    environment:
      - APP_TIME_ZONE=America/Los_Angeles

volumes:
  foresight_data:
```

Run it:
```bash
docker compose up -d
```

## Configuration

You can configure the application using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTH_USERNAME` | Override the database-stored username | *(Database)* |
| `AUTH_PASSWORD` | Override the database-stored password | *(Database)* |
| `SECRET_KEY_BASE` | Optional externally managed session encryption key; must contain at least 30 bytes | *(Generated once in persistent storage)* |
| `SECRET_KEY_BASE_FILE` | Persistent generated-key path | `/rails/storage/.secret_key_base` |
| `APP_TIME_ZONE` | Rails application timezone; accepts IANA or Rails names (e.g., `America/New_York`) | `Pacific Time (US & Canada)` |
| `RAILS_LOG_LEVEL` | Logging verbosity | `info` |
| `SOLID_QUEUE_IN_PUMA` | Run scheduled work and background jobs in the web container | `true` |
| `THRUSTER_HTTP_PORT` | Container listener port for Thruster | `8080` |

`APP_TIME_ZONE` controls application dates, session timestamps, projections, and
scheduled work. Invalid values stop the application during startup so it cannot
silently calculate dates in an unintended zone. The default remains Pacific time
for compatibility with existing installations. The operating-system `TZ`
variable is not used as the Rails application timezone.

Foresight keeps exactly one application-settings record. During an upgrade from
a database containing duplicates, the migration reports the affected row IDs and
keeps a complete credential-bearing row first; ties are resolved by earliest
creation time and then lowest ID. The database rejects all later duplicates.

### Scheduled maintenance

The supported single-container installation runs Solid Queue inside Puma by
default. It refreshes recurring projections through a fixed 24-month operational
horizon each day, removes authentication audit events older than 90 days, and
clears completed queue records. Schedule times use `APP_TIME_ZONE`. Financial
resource audit events are retained. Failed sign-in events record request metadata
only; submitted usernames and passwords are never stored in the audit log.

For a split-process deployment, set `SOLID_QUEUE_IN_PUMA=false` on the web
container and run `bin/jobs` as exactly one additional service against the same
persistent storage. The value `false` is parsed as false rather than merely as a
non-empty environment string. Solid Queue records recurring executions with a
database uniqueness constraint, so overlapping schedulers cannot dispatch the
same scheduled occurrence twice while finished records are retained.

Solid Queue schedules the next occurrence after startup; it does not replay each
tick missed during downtime. Foresight's maintenance jobs are therefore
idempotent and state-based: the next projection run fills every missing expected
occurrence through 24 months from the current application-local date, and the
next audit run removes every event beyond the retention boundary. Job errors
remain in container logs and Solid Queue's failed execution records for
diagnosis. Creating or editing a recurring rule runs the same materializer
transactionally; dashboard and account page reads never create or modify
financial records.

### Security automation

The default branch is audited daily and on demand. `bin/security-audit` refreshes
the Ruby advisory database, checks the resolved bundle (including explicitly
pinned default gems), audits Importmap dependencies, and runs Brakeman. A pinned
Trivy action using Trivy 0.74.0 scans the built production image's OS and library packages.
The image job fails on HIGH or CRITICAL findings that have a published fix;
unfixed findings remain visible in the retained full report without blocking all
future updates. Update the affected dependency or image base and rerun the
workflow to prove recovery.

Ruby can retain an older bundled copy of a default gem on disk after Bundler pins
and activates a fixed version. `config/security.yml` records the minimum safe
versions for those overrides. The image policy suppresses a stale bundled-copy
finding only when the resolved lockfile version is newer and meets that floor;
findings against the active pinned version still fail.

### Session encryption key

On first startup, Foresight generates a cryptographically random session key at
`/rails/storage/.secret_key_base`. The file belongs to the container user, is
readable only by that user, and is reused across restarts. Keep `/rails/storage`
on persistent storage. The generated key is installation-specific and is not part
of a portable database backup.

You may instead supply `SECRET_KEY_BASE` from a secret manager. It must be at
least 30 bytes and should be generated randomly. An explicitly supplied value
always takes precedence over the generated file. Removing the environment value
switches back to the stored generated key; adding or changing it switches to the
external key. Either change invalidates existing browser sessions and requires
users to sign in again.

Images published before this behavior was introduced contained a shared key and
must be treated as permanently disclosed. Upgrading to a fixed image generates a
new installation key and invalidates sessions that used the old image key. If an
external key was already configured, rotate it through your secret manager when
your deployment policy requires it. Startup fails rather than using an unsafe or
unreadable key file, including incorrectly owned, overly permissive, symbolic-link,
or read-only bind-mount configurations.

### Backup and restore

`bin/backup` creates a transactionally consistent snapshot of the primary
production database using SQLite's online backup API. It includes financial
records, settings, and audit history. It does not copy a live WAL file, and it
does not include the rebuildable cache database, Solid Queue's operational
database, or `.secret_key_base`. The resulting archive contains the database
plus creation time, schema version, SHA-256 checksum, integrity result, and
material record counts. Publication is atomic and mode `0600`; an existing
archive is never overwritten.

For the standard container, create a backup while Foresight is running, then
copy it off the Docker volume:

```bash
docker exec foresight mkdir -p /rails/storage/backups
docker exec foresight bin/backup \
  --output /rails/storage/backups/foresight-backup-2026-09-10.tar.gz
docker cp \
  foresight:/rails/storage/backups/foresight-backup-2026-09-10.tar.gz .
```

Keep multiple generations off-host. Choose retention appropriate to your data,
encrypt archives at rest and in transit with your normal backup system, and
periodically restore one into a disposable volume to prove recovery. Foresight
provides integrity and completeness checks, not archive encryption or remote
storage.

Restore always validates into a separate temporary database. It verifies the
archive checksum, `PRAGMA integrity_check`, schema compatibility, and material
record counts before atomically publishing the target. Older schemas are
accepted and migrated by normal application startup; backups from a newer
Foresight schema are rejected. An existing target is refused unless `--replace`
is explicit. Replacement also refuses live WAL state and preserves the previous
database beside the target as `.before-restore-<timestamp>`.

Stop the application cleanly before replacing its database:

```bash
docker stop foresight
docker run --rm --user 1000:1000 \
  --entrypoint /rails/bin/restore \
  -v foresight_data:/rails/storage \
  -v "$PWD:/backup:ro" \
  ghcr.io/mrecek/foresight:latest \
  --archive /backup/foresight-backup-2026-09-10.tar.gz \
  --target /rails/storage/production.sqlite3 \
  --replace
docker start foresight
```

The destination's installation secret is never imported from the archive. A
new destination generates its own key on startup, invalidating sessions from
the source installation; an existing destination retains its independently
managed key. Cache state rebuilds naturally. Queue state is intentionally
excluded because Foresight's queued maintenance is idempotent and derived from
the primary database; the scheduler recreates future work after startup.

## Deployment

Foresight runs on HTTP by default. For production self-hosting, it's recommended to put the app behind a reverse proxy that handles HTTPS, such as:

- **[Caddy](https://caddyserver.com/)**
- **[Traefik](https://traefik.io/)**
- **[Nginx Proxy Manager](https://nginxproxymanager.com/)**
- **[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)**

## Built-in Agent Skills

This repo includes two built-in cross-agent skills under `.agents/skills/`:

- `foresight-dev` for local setup, runtime, demo/test mode, and validation workflows
- `foresight-git-workflow` for explicit-request-only git operations and CI/CD workflow guidance

The canonical skill definitions live at:

- `.agents/skills/foresight-dev/SKILL.md`
- `.agents/skills/foresight-git-workflow/SKILL.md`

## Development

Want to build from source or contribute?

```bash
bundle install
bin/rails db:setup
bin/dev
```

For an easier local testing flow, seed demo data and run in test mode:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
TEST_MODE=true bin/dev
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution expectations and the local validation workflow.

## License

MIT
