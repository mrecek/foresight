# Testing And Validation

Use this reference when you need to verify behavior locally during normal development work.

## Primary Test Commands

Run the complete local contract, including the production container check, with:

```bash
bin/validate
```

Use `bin/validate --ci` for every non-container stage or `bin/validate test` for
the full test suite alone. Each failure names its contract stage.

Run a targeted test directly with:

```bash
bin/rails test test/models/recurring_rule_test.rb
```

## Targeted Test Commands

Run a file group through Rails:

```bash
bin/rails test test/services
bin/rails test test/models
```

## Code Quality

Run focused contract stages:

```bash
bin/validate lint
bin/validate security-ruby security-js
bin/validate runtime architecture
bin/validate container
```

Use this skill for local validation only. Commit, PR, merge, and CI policy belong to `foresight-git-workflow`.
