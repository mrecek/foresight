# Local Setup

Use this reference when you need to bootstrap or run Foresight locally.

## Platform

- macOS, Linux, or WSL
- the exact Ruby in `.ruby-version`
- SQLite 3

Rails owns the JavaScript and Tailwind toolchain; Node.js is not a project requirement.

## Setup With mise

```bash
mise trust
mise run setup
mise run dev
```

mise is a convenience layer. Its tasks delegate to repository commands.

## Setup Without mise

Install the Ruby version named by `.ruby-version`, then run:

```bash
bin/setup --skip-server
bin/dev
```

Visit `http://localhost:3000`. `bin/setup` is idempotent and installs the tracked Git hooks in a Git checkout.

## Completion

Setup is complete when `bin/check-runtime-parity` passes, dependencies are installed, the development database is prepared, and `bin/dev` reaches a healthy application at `http://localhost:3000/up`.

Use `bin/validate container` for the supported production-image build and smoke test.
