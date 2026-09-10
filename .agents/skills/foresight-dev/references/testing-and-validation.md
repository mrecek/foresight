# Testing And Validation

Use this reference when you need to verify behavior locally during normal development work.

## Contract

Run the complete local contract, including the production container check, with:

```bash
bin/validate
```

Use `bin/validate --ci` for every non-container stage. Use `bin/validate test`
for the full test suite alone. Each failure names its contract stage; inspect
`config/validation.rb` when exact stage contents matter.

Run a targeted test directly with:

```bash
bin/rails test test/models/recurring_rule_test.rb
```

## Focused Work

Run a file group through Rails:

```bash
bin/rails test test/services
bin/rails test test/models
```

Run focused contract stages when they prove the changed surface:

```bash
bin/validate lint
bin/validate security-ruby security-js
bin/validate runtime architecture
bin/validate container
```

Use this skill for local validation only. Commit, PR, merge, and CI policy belong to `foresight-git-workflow`.

## Completion

Every changed behavior has a focused proof, every affected contract stage passes, and reported failures are resolved or explicitly handed back as blockers. Whole-repository or release validation requires a passing `bin/validate`.
