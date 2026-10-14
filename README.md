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

The included Compose configuration is the easiest supported deployment. Existing single-container installations must follow the [upgrade instructions](#deployment-contract) before updating:

```bash
git clone https://github.com/mrecek/foresight.git
cd foresight
docker compose up -d
```

Open `http://localhost:3000` and complete the initial setup. Compose runs one web container and one background-jobs container. Both use the same image and store the databases and installation-specific session key in the `foresight_data` volume. Jobs start after the web container finishes database preparation and becomes healthy.

To run the same image without Compose:

```bash
docker run -d \
  --name foresight \
  --restart unless-stopped \
  --stop-timeout 30 \
  -p 3000:8080 \
  -v foresight_data:/rails/storage \
  -e APP_TIME_ZONE=UTC \
  ghcr.io/mrecek/foresight:latest
```

After the web container reports healthy, start its jobs container:

```bash
docker run -d \
  --name foresight-jobs \
  --restart unless-stopped \
  --stop-timeout 30 \
  --no-healthcheck \
  -v foresight_data:/rails/storage \
  -e APP_TIME_ZONE=UTC \
  ghcr.io/mrecek/foresight:latest bin/jobs
```

Keep both containers on the same image digest and provide the same application configuration and session-key settings to each. The jobs container has no HTTP listener; its process is supervised by the container runtime.

The image supports `linux/amd64` and `linux/arm64`. `latest` follows the newest accepted release. Each accepted build also has an immutable `release-<UTC time>-<source SHA>-<run>-<attempt>` tag for pinning and rollback.

## Deployment contract

Foresight can run under Docker, Compose, Kubernetes, or another OCI-compatible platform. A deployment needs:

- one web container and one jobs container;
- persistent, writable storage mounted at `/rails/storage`;
- HTTP traffic sent to container port `8080`;
- an HTTP health probe against `/up`; and
- TLS terminated by a reverse proxy or ingress in front of the container.

Run both containers on the same host against the same local volume. The primary database, cache, and job queue are SQLite files; SQLite coordinates their writes locally. Do not scale either service across hosts or use a network filesystem. Containers run as non-root user and group `1000:1000`; bind-mounted storage must be writable by that identity.

The default command starts Puma and prepares pending database migrations. The jobs container runs `bin/jobs` independently. A small init process forwards shutdown signals, including during startup, and reaps exited children. Give each container at least 30 seconds to shut down gracefully. Disable the image's HTTP health check for the jobs container, as shown above; `bin/jobs check` validates configuration and is not a worker liveness check.

On Kubernetes, place both containers in one single-replica Pod sharing the same persistent volume. Use a StatefulSet or a Deployment with `Recreate` strategy so an upgrade never overlaps two application replicas. Run `bin/rails db:prepare` in an init container before either starts, and use the same pinned image digest, storage mount, and application environment for all three. Probe `/up` on the web container; the jobs container does not expose HTTP.

When upgrading a single-container deployment, add the jobs container even if you never set `SOLID_QUEUE_IN_PUMA`. Remove any explicit `SOLID_QUEUE_IN_PUMA=true`; that legacy setting now fails startup with migration instructions. An explicit `false` remains accepted. The included Compose file already implements the new layout; set `FORESIGHT_IMAGE` to a release tag or digest to pin both services together.

For upgrades, stop both services before pulling and starting the new image so old jobs cannot run while the database is being migrated:

```bash
docker compose down
docker compose pull
docker compose up -d
```

The named data volume is preserved by `docker compose down`. Back up the primary database before an upgrade.

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `APP_TIME_ZONE` | Application dates, projections, and schedules; accepts IANA or Rails timezone names | `Pacific Time (US & Canada)` |
| `AUTH_MODE` | Installation-wide sign-in method: `password` or `oidc` | `password` |
| `AUTH_USERNAME` | Override the database-stored login username | Database value |
| `AUTH_PASSWORD` | Override the database-stored login password | Database value |
| `APP_URL` | Public origin used for the exact OIDC callback URL | Required for OIDC |
| `OIDC_ISSUER` | Exact HTTPS issuer advertised by one OpenID Connect provider | Required for OIDC |
| `OIDC_CLIENT_ID` | Provider-issued client identifier | Required for OIDC |
| `OIDC_CLIENT_SECRET` | Provider-issued client secret | One OIDC secret source is required |
| `OIDC_CLIENT_SECRET_FILE` | File containing the provider-issued client secret | Alternative to `OIDC_CLIENT_SECRET` |
| `OIDC_ALLOWED_SUBJECTS` | Comma-separated allowlist of exact OIDC subject identifiers | Required for OIDC |
| `OIDC_PROVIDER_NAME` | Provider label shown on the sign-in button | `OpenID Connect` |
| `OIDC_AUTHORIZATION_ENDPOINT` | Public HTTPS authorization endpoint when discovery cannot be used | Optional; explicit endpoints are all-or-none |
| `OIDC_TOKEN_ENDPOINT` | Server-side token endpoint for explicit endpoint mode | Optional |
| `OIDC_USERINFO_ENDPOINT` | Server-side user-info endpoint for explicit endpoint mode | Optional |
| `OIDC_JWKS_URI` | Server-side signing-key endpoint for explicit endpoint mode | Optional |
| `OIDC_ALLOW_INSECURE_BACKCHANNEL` | Allow explicit server-side endpoints to use HTTP on a trusted private network | `false` |
| `SESSION_ABSOLUTE_TIMEOUT_MINUTES` | Maximum session lifetime, from 1 minute through 24 hours | `720` |
| `SECRET_KEY_BASE` | Externally managed session-encryption key of at least 30 bytes | Generated per installation |
| `SECRET_KEY_BASE_FILE` | Path for the generated installation key | `/rails/storage/.secret_key_base` |
| `RAILS_LOG_LEVEL` | Application logging verbosity | `info` |
| `PORT` | Container listener port | `8080` |

An unset `SECRET_KEY_BASE` is safe: first startup generates a cryptographically random key in persistent storage with private permissions. Supplying or changing an external key invalidates existing browser sessions. Startup fails when the configured key or generated-key file is unsafe, unreadable, or too short.

Invalid application timezones also fail startup instead of silently shifting financial dates.

## Single sign-on

Foresight can delegate sign-in to one standards-compliant OpenID Connect provider while keeping its existing single shared workspace. Register this exact callback with the provider:

```text
https://foresight.example.com/auth/openid_connect/callback
```

Then configure both containers:

```yaml
x-oidc: &oidc
  environment:
    AUTH_MODE: oidc
    APP_URL: https://foresight.example.com
    OIDC_ISSUER: https://identity.example.com/realms/foresight
    OIDC_CLIENT_ID: foresight
    OIDC_CLIENT_SECRET_FILE: /run/secrets/oidc_client_secret
    OIDC_ALLOWED_SUBJECTS: exact-owner-subject,exact-backup-subject
    OIDC_PROVIDER_NAME: My Identity Provider
  secrets:
    - oidc_client_secret

services:
  foresight:
    <<: *oidc
  jobs:
    <<: *oidc

secrets:
  oidc_client_secret:
    file: ./oidc-client-secret.txt
```

For Kubernetes, provide the same variables in the pod and source the client secret from a Secret:

```yaml
env:
  - name: AUTH_MODE
    value: oidc
  - name: APP_URL
    value: https://foresight.example.com
  - name: OIDC_ISSUER
    value: https://identity.example.com/realms/foresight
  - name: OIDC_CLIENT_ID
    value: foresight
  - name: OIDC_ALLOWED_SUBJECTS
    value: exact-owner-subject
  - name: OIDC_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: foresight-oidc
        key: client-secret
```

Use the provider's opaque `sub` identifier, not an email address, in `OIDC_ALLOWED_SUBJECTS`. Foresight validates discovery metadata when discovery is enabled, and always validates issuer, signature, audience, expiry, state, nonce, and PKCE before applying this allowlist. It does not retain access, refresh, or ID tokens.

By default, Foresight discovers every provider endpoint from `OIDC_ISSUER`. If a
deployment cannot route server-side requests through the provider's public
hostname, configure all four explicit endpoint variables. Keep
`OIDC_AUTHORIZATION_ENDPOINT` public and HTTPS because the browser is redirected
there. The token, user-info, and JWKS endpoints may point at a private
backchannel; HTTP requires the deliberate
`OIDC_ALLOW_INSECURE_BACKCHANNEL=true` opt-in and should be used only on a
trusted private network. Token issuer validation still uses the exact public
`OIDC_ISSUER` in either mode.

```yaml
environment:
  OIDC_AUTHORIZATION_ENDPOINT: https://identity.example.com/oauth2/authorize
  OIDC_TOKEN_ENDPOINT: http://identity-backchannel:8080/oauth2/token
  OIDC_USERINFO_ENDPOINT: http://identity-backchannel:8080/oauth2/userinfo
  OIDC_JWKS_URI: http://identity-backchannel:8080/oauth2/jwks
  OIDC_ALLOW_INSECURE_BACKCHANNEL: "true"
```

OIDC mode exposes no password form or fallback route. For operator recovery, restart with `AUTH_MODE=password`, remove the OIDC variables, and supply both `AUTH_USERNAME` and `AUTH_PASSWORD`. Signing out ends only the local Foresight session; it does not sign the person out of other applications at the identity provider.

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

The production image runs Puma behind your reverse proxy and starts Solid Queue through `bin/jobs` in a second container. Both run without root privileges and share persistent storage. Web startup prepares pending database migrations and includes an HTTP health check.

## Maintenance and security

Routine gem patch and minor updates are proposed by Dependabot and may merge only after the complete pull-request validation contract passes. Ruby patch releases update the local runtime declaration and digest-pinned container base together. GitHub Actions, Docker architecture changes, major dependency versions, and Ruby minor or major upgrades remain under human review.

The release workflow rebuilds the production image daily against current Debian repositories. Every candidate passes application validation, smoke tests on native `linux/amd64` and `linux/arm64` runners, including real queued maintenance and three strict shutdown/restart cycles for web and jobs, fixable HIGH/CRITICAL vulnerability checks, manifest checks, and provenance/SBOM verification before publication. Scheduled builds publish even when package versions are unchanged. This also picks up dependency updates merged by automation whose GitHub token suppresses push-triggered releases; human pushes still release immediately. GitHub schedules are best effort, so daily publication is an expectation rather than a delivery guarantee.

A separate daily audit scans the exact published digest and checks the effective runtime gems inside each platform image. Its narrowly scoped exception for an inactive bundled default gem requires the loaded replacement to satisfy the specific advisory's safe version. Unknown advisories fail closed. The audit reports unfixed HIGH/CRITICAL findings and blocks fixable findings; it also fails if the published build is older than seven days. Audit failures point to the affected dependency or release workflow without dispatching another rebuild.

Source releases, refreshes, retention, and rollback share one serialized production lane. Manual rollback selects a retained immutable release tag and supplies the expected current digest, preventing an operator from overwriting a newer release accidentally. Manual retention runs are dry-run by default; scheduled cleanup keeps the latest 30 promoted digests, preserves the current release and attestation metadata, and expires candidate-only artifacts after 14 days.

Foresight is maintained primarily for the author's own use and shared in the hope that it is useful to other self-hosters. Bug reports are welcome; feature work is intentionally kept focused.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for supported development environments, setup, validation, and contribution expectations.

## License

Foresight is available under the [MIT License](LICENSE).
