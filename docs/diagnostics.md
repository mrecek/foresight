# Installation diagnostics

Run `bin/doctor` for a concise local report or `bin/doctor --json` for automation.
For Compose installations:

```bash
docker compose exec foresight bin/doctor --json
```

Use the same application environment and storage as the web and jobs roles. The
command uses Bundler and read-only SQLite connections without initializing Rails.
It works when required application state is absent, and the image entrypoint
routes it before session-key creation. It makes no provider or registry requests.

## Report and exit status

| Exit | Meaning |
| --- | --- |
| `0` | Every required check passes |
| `1` | At least one required check fails |
| `2` | Invalid invocation or diagnostic/runtime failure |

JSON output is one object with `schema_version: 1`, `status`, runtime versions and
`checks`. Each check has an `id`, `status`, and `required` flag, plus evidence or a
next action. Supported check statuses are `pass`, `fail`, and `unknown`.
`maintenance_coverage` is an optional `unknown`: it does not change the exit
status. A healthy report establishes only the checks' stated scope.

The checks cover environment/authentication/timezone configuration, production
session-key configuration, database configuration, file/directory access, source
schema versions, required settings, and production queue evidence. Store names
come from `config/database.yml`, including configured database URL overrides.

Schema differences report failure for pending or unknown migration versions.
Investigate the source and database history before choosing a preparation or
recovery action. Diagnostics never invent or apply a migration.

Worker activity is a recent `Worker` heartbeat, observed within five minutes.
The ready-work check flags a wait longer than fifteen minutes. These are
observation thresholds, not processing deadlines. Retained failed executions
also fail the report. SQL statements have a one-second execution limit and a
100-millisecond lock wait. Checks report unavailable evidence as failure and
continue where independent evidence remains accessible.

A heartbeat proves recent process activity. Neither an empty queue nor a
heartbeat proves successful scheduled maintenance. The report explicitly leaves
financial occurrence coverage and durable last-success evidence unknown. Inspect
the actual scheduled execution evidence when diagnosing maintenance, and use
`bin/transfers` for a full, explicit transfer-pair audit. `/up` remains an HTTP
liveness check.

## Inspection and preparation

The command does not create databases/settings/session keys, migrate, seed,
enqueue, retry, or repair work. Storage checks inspect permissions without a
write probe. Read-only storage can therefore pass database inspection while
failing the application's writable-storage requirement. SQLite readers may use
WAL/SHM coordination files for a live WAL database; application contents and
installation state remain unchanged. The command never uses SQLite's immutable
mode on a live database.

Required settings belong to explicit `bin/rails db:prepare`, which is idempotent
and preserves configured values. Rails initialization itself does not prepare
installation state. Preparation and repair are separate operator actions.

Reports omit secret values, financial records, raw SQL and exception messages.
Check identifiers and suggested actions provide the diagnostic interface; log
scraping or dependence on exception wording is unnecessary.
