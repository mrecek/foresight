# Runtime And Demo Mode

Use this reference for browser testing, demo data, and process ownership.

## Test Mode

```bash
TEST_MODE=true bin/dev
```

Test mode bypasses authentication and session timeout and shows a visible banner.
It cannot activate in production. Use ordinary authentication when validating
login, logout, or session expiry.

## Disposable Demo Database

`SEED_DEMO_DATA=true bin/rails db:seed` **replaces all financial data in the
selected database**: accounts, transactions, recurring rules, categories and
groups. Existing configured credentials are preserved. The seed creates
`demo` / `demo1234` only when password setup is incomplete.

With the default password-authentication configuration (no environment credential
overrides), create a separate, fresh development database for a guaranteed demo login.
Run these commands in the same terminal so preparation, seeding and the server
use the same database:

```bash
preview_dir=$(mktemp -d "${TMPDIR:-/tmp}/foresight-preview.XXXXXX")
export DATABASE_URL="sqlite3:${preview_dir}/preview.sqlite3"
export RAILS_ENV=development
export TEST_MODE=false
bin/rails db:prepare
SEED_DEMO_DATA=true bin/rails db:seed
bin/dev
```

Sign in with `demo` / `demo1234`. For authentication-free browser work, replace
the last command with `TEST_MODE=true bin/dev`.

Record the temporary directory and process/session identifier. Remove the
owned temporary directory after its server has stopped and the user no longer
needs the demo. Keep a user-requested preview running until the user is done.

## Stopping The Dev Server

Stop `bin/dev` with `Ctrl+C` when its terminal is attached. For a detached run,
retain its process or session identifier, send that exact process `TERM`, and
confirm it exited.

When ownership is unknown, inspect the process and leave it running until its
identity is established. Port ownership alone is not proof of task ownership.

Completion means task-owned validation processes have exited and released their
ports; a preview explicitly requested by the user may remain running.
