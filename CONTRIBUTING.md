# Contributing to Foresight

Foresight is a personal project published for self-hosters. Bug reports, focused fixes, documentation improvements, and security hardening are welcome. Please open an issue before starting a substantial feature or architectural change so its maintenance cost and fit can be discussed first.

Be kind and keep reports free of credentials or personal financial data.

## Development environment

Supported development environments are macOS, Linux, and WSL. Docker is required for the complete production-image validation.

The optional mise setup installs the supported Ruby and delegates to the repository's own commands:

```bash
mise trust
mise run setup
mise run dev
```

Without mise, install the exact Ruby version printed by `bin/ruby-version`, then run:

```bash
bin/setup --skip-server
bin/dev
```

Open `http://localhost:3000`. `bin/setup` installs dependencies, prepares the database, clears disposable local state, and configures the repository's Git hooks.

Node.js is not required; Rails owns the Importmap and Tailwind toolchain.

## Test data

For disposable local data and authentication-free browser testing:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
TEST_MODE=true bin/dev
```

Test mode cannot activate in production.

## Validation

Use focused checks while working and run the complete contract before opening a pull request:

```bash
bin/validate
```

This checks runtime and workflow parity, style, dependency and application security, Rails autoloading, database migrations, financial transfer invariants, the complete automated test suite, imported container-cache freshness, and a production-container build and smoke test.

Useful focused commands include:

```bash
bin/validate test
bin/validate lint
bin/validate security-ruby security-js
bin/validate runtime architecture
bin/test test/services
bin/test test/services/transaction_change_test.rb:15 --seed 1234
```

`bin/test` runs the complete suite by default, including browser and standalone
process tests. It accepts Rails file, directory, line, name and seed selections;
a selection that executes no tests fails. Use `--help` for runner options.

Required singleton settings are created by `bin/rails db:prepare`, independently
of application initialization. For installation inspection, use `bin/doctor` or
`bin/doctor --json`; see [Installation diagnostics](docs/diagnostics.md).

[Financial operations](docs/financial-operations.md) maps application behavior to
its operation and focused tests. Operations own financial transaction/audit
boundaries; controllers translate HTTP; models own record-local validation and
associations; jobs invoke application operations. Calculation objects derive
dates and balances without owning persistence side effects.

The test stage includes a deliberately small real-browser suite for the critical authentication and financial workflows. Browser failures leave screenshots in `tmp/system-test-artifacts`.

## Pull requests

- Use a focused branch and Conventional Commit subjects.
- Keep one pull request centered on one coherent outcome.
- Include the reason for the change and the validation you ran.
- Add regression coverage for changed behavior.
- Keep deployment guidance portable and free of private infrastructure details.

Pull requests merge by squash after all required checks pass. Dependency updates outside the low-risk Bundler patch/minor lane require human review.
