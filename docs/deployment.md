# Foresight deployment

The image at `ghcr.io/mrecek/foresight` supports Linux AMD64 and ARM64. Use an
immutable release tag or digest to pin both containers. The bundled [Compose file](../compose.yaml)
runs both roles and waits for web readiness before starting jobs.

## Deployment contract

Foresight runs under Docker, Compose, Kubernetes, or another OCI-compatible
platform.

- Run one web container and one jobs container.
- Mount persistent, writable storage at `/rails/storage`.
- Send HTTP traffic to container port `8080` and probe `/up` on web.
- Terminate TLS at a reverse proxy or ingress.

Run both containers on the same host against the same local volume. SQLite
uses WAL for the primary database, cache, and job queue and requires a local
filesystem. Make bind-mounted storage writable by user and group `1000:1000`.

The default command starts Puma and prepares pending database migrations. The jobs container runs `bin/jobs` independently. A small init process forwards shutdown signals, including during startup, and reaps exited children. Give each container at least 30 seconds to shut down gracefully. Disable the image's HTTP health check for the jobs container. Use `bin/jobs check` to validate job configuration.

On Kubernetes, place both containers in one single-replica Pod sharing the same persistent volume. Use a StatefulSet or a Deployment with `Recreate` strategy so an upgrade never overlaps two application replicas. Run `bin/rails db:prepare` in an init container before either starts, and use the same pinned image digest, storage mount, and application environment for all three. Probe `/up` on the web container; the jobs container does not expose HTTP.

The [upgrade procedure](../.agents/skills/foresight-dev/references/installation.md#upgrade)
covers older single-container deployments.

## Configuration

| Variable | Purpose | Default |
|---|---|---|
| `APP_TIME_ZONE` | Application dates, projections, and schedules. Accepts IANA or Rails timezone names | `Pacific Time (US & Canada)` (bundled Compose uses `UTC`) |
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
| `OIDC_AUTHORIZATION_ENDPOINT` | Public HTTPS authorization endpoint when discovery cannot be used | Optional. Supply all four explicit endpoints together |
| `OIDC_TOKEN_ENDPOINT` | Server-side token endpoint for explicit endpoint mode | Optional |
| `OIDC_USERINFO_ENDPOINT` | Server-side user-info endpoint for explicit endpoint mode | Optional |
| `OIDC_JWKS_URI` | Server-side signing-key endpoint for explicit endpoint mode | Optional |
| `OIDC_ALLOW_INSECURE_BACKCHANNEL` | Allow explicit server-side endpoints to use HTTP on a trusted private network | `false` |
| `SESSION_ABSOLUTE_TIMEOUT_MINUTES` | Maximum session lifetime, from 1 minute through 24 hours | `720` |
| `SECRET_KEY_BASE` | Externally managed session-encryption key of at least 30 bytes | Generated per installation |
| `SECRET_KEY_BASE_FILE` | Path for the generated installation key | `/rails/storage/.secret_key_base` |
| `RAILS_LOG_LEVEL` | Application logging verbosity | `info` |
| `PORT` | Container listener port | `8080` |

Without an external `SECRET_KEY_BASE`, first startup generates a private key in persistent storage. Supplying or changing an external key invalidates existing browser sessions. Startup fails when the configured key or generated-key file is unsafe, unreadable, or too short.

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

On Kubernetes, set the same variables in the pod and source
`OIDC_CLIENT_SECRET` from a Secret.

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

Signing out ends the local Foresight session. Other provider sessions continue.

## Data and recovery

Keep persistent storage at `/rails/storage`. A backup captures the primary
SQLite database with integrity and schema evidence. Keep encrypted copies off
the application host and test restores periodically. The generated session
key is excluded from backup archives. A restored installation creates or keeps
its own key.

See the [installation procedures](../.agents/skills/foresight-dev/references/installation.md)
for container startup, upgrades, sign-in recovery, and backups. The
[diagnostics reference](diagnostics.md) explains the output of `bin/doctor`.
