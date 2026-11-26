# Operate an installation

Read the [deployment contract](../../../../docs/deployment.md) for runtime,
storage, and authentication requirements. Use the target environment's
deployment workflow for managed installations.

## Start with Docker

Prefer the bundled Compose file. For plain Docker, resolve one verified image
to an immutable tag or digest and set `FORESIGHT_IMAGE` to that reference:

```bash
docker run -d --name foresight --restart unless-stopped --stop-timeout 30 \
  -p 3000:8080 -v foresight_data:/rails/storage -e APP_TIME_ZONE=UTC \
  "$FORESIGHT_IMAGE"
```

After the web container reports healthy, start the worker:

```bash
docker run -d --name foresight-jobs --restart unless-stopped --stop-timeout 30 \
  --no-healthcheck -v foresight_data:/rails/storage -e APP_TIME_ZONE=UTC \
  "$FORESIGHT_IMAGE" bin/jobs
```

Apply identical application and session-key settings to both containers.
Check `/up` on web and confirm the worker completes queued work.

## Upgrade

Back up the primary database. Select one verified image reference for both
roles. To migrate a single-container install, add the standalone jobs role
and remove any explicit `SOLID_QUEUE_IN_PUMA=true`, which prevents startup.

Stop both roles before the new image runs migrations. With the bundled Compose
file, set `FORESIGHT_IMAGE` to the selected release in the deployment
configuration and run:

```bash
docker compose down
docker compose pull
docker compose up -d
```

Compose preserves the named volume. Check `/up`, sign-in, and queued maintenance
with both roles running the intended image. For Kubernetes, use the installation's
own release workflow and verify the migration init container completed before
both roles started.

## Diagnose

Run `bin/doctor --json` with the installation's application environment and
storage, for example `docker compose exec foresight bin/doctor --json`.
Interpret the result with the [diagnostics reference](../../../../docs/diagnostics.md).
Use the output for configuration, storage, schema, and worker checks.

If an identity provider outage requires temporary password recovery, set
`AUTH_MODE=password`, remove the OIDC variables, and supply both
`AUTH_USERNAME` and `AUTH_PASSWORD` through the installation's secret store.
Verify sign-in, then restore the original OIDC configuration after recovery.

## Back up and restore

Use `bin/backup` to take an online SQLite backup of the primary database.
For a Docker web container named `foresight`:

```bash
docker exec foresight mkdir -p /rails/storage/backups
docker exec foresight bin/backup \
  --output /rails/storage/backups/foresight-backup.tar.gz
docker cp foresight:/rails/storage/backups/foresight-backup.tar.gz .
```

Read `bin/restore --help` before running a restore. Verify a selected backup in
an isolated destination first. For production replacement, stop web and jobs,
preserve current data, and use the guarded replacement path. Restore validates
the temporary database and rejects unsupported newer schemas. After recovery,
check representative data, sign-in, and jobs, then take a fresh backup.
