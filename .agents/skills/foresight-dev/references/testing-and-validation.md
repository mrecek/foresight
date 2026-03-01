# Testing And Validation

Use this reference when you need to verify behavior locally during normal development work.

## Primary Test Commands

Run the full local suite with:

```bash
bin/test
```

Run the fast model and service subset directly with:

```bash
ruby -Itest -Ilib test/models/*_test.rb test/services/*_test.rb
```

## Targeted Test Commands

Run a specific file:

```bash
ruby -Itest -Ilib test/models/recurring_rule_test.rb
ruby -Itest -Ilib test/services/recurrence_calculator_test.rb
ruby -Itest -Ilib test/services/transaction_grouper_test.rb
```

Run a file group:

```bash
ruby -Itest -Ilib test/services/*_test.rb
ruby -Itest -Ilib test/models/*_test.rb
```

Run verbose output when you need more detail:

```bash
ruby -Itest -Ilib test/**/*_test.rb --verbose
```

## Code Quality

Use the standard local quality tools:

```bash
bundle exec rubocop
bin/brakeman --no-pager
```

Use this skill for local validation only. Commit, PR, merge, and CI policy belong to `foresight-git-workflow`.
