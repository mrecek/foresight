# Development Guide

This guide is for developers who want to build Foresight from source or contribute to the project.

## Requirements

- **Ruby**: 3.4+
- **Database**: SQLite 3
- **Runtime**: Node.js (for asset compilation) or environment that supports `tailwindcss-ruby`

## Local Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/mrecek/foresight.git
   cd foresight
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   bin/rails db:setup
   ```

4. **Start the development server**
   ```bash
   bin/dev
   ```
   Visit `http://localhost:3000`.

## Testing

### Test Mode (For Development & AI Agents)

Test mode allows running the application **without authentication**, making it easy for developers and AI agents to access the app for testing.

**Enable test mode:**
```bash
TEST_MODE=true bin/dev
```

When test mode is active:
- All authentication is bypassed (no login required)
- Session timeout is disabled
- A visible banner appears at the top of the page confirming test mode is active
- **Security**: Test mode is automatically disabled in production environments

### Demo Data & Credentials

Seed the database with sample accounts, recurring rules, and transactions:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
```

This also creates demo login credentials:
- **Username:** `demo`
- **Password:** `demo1234`

### Recommended Workflows

**For AI agents and automated testing:**
```bash
# One-time setup
SEED_DEMO_DATA=true bin/rails db:seed

# Run with auth bypassed
TEST_MODE=true bin/dev
```

**For manual testing with real authentication:**
```bash
SEED_DEMO_DATA=true bin/rails db:seed
bin/dev
# Log in with: demo / demo1234
```

### Stopping the Development Server

The development server runs via `foreman` and occupies port 3000. To stop it:

**From the terminal where it's running:**
Press `Ctrl+C`

**If you don't have access to that terminal:**
```bash
# Kill the dev server process
pkill -f "bin/dev"

# If port 3000 is still occupied
lsof -ti:3000 | xargs kill -9
```

**For AI agents:** Always stop the development server after completing your tests to free up port 3000. Use `pkill -f "bin/dev"` before finishing your session.

### Automated Tests

The project includes comprehensive unit and integration tests for models and services.

**Run the full test suite:**
```bash
bin/test
```

Or run tests directly:
```bash
ruby -Itest -Ilib test/models/*_test.rb test/services/*_test.rb
```

**Run specific test files:**
```bash
ruby -Itest -Ilib test/models/recurring_rule_test.rb
ruby -Itest -Ilib test/services/recurrence_calculator_test.rb
ruby -Itest -Ilib test/services/transaction_grouper_test.rb
```

**Run tests matching a pattern:**
```bash
ruby -Itest -Ilib test/services/*_test.rb      # All service tests
ruby -Itest -Ilib test/models/*_test.rb        # All model tests
```

**Run tests with verbose output:**
```bash
ruby -Itest -Ilib test/**/*_test.rb --verbose
```

**Test Coverage:**
- **171 tests, 408 assertions**
- Models: RecurringRule (31 tests), Transaction (33 tests), Account (31 tests), Setting (30 tests)
- Services: RecurrenceCalculator (28 tests), TransactionGrouper (18 tests)
- Coverage includes: validations, callbacks, date calculations, transaction generation, transfer handling, frequency-based grouping, account deletion protection, session timeout security, balance projections

**CI Integration:**
Tests run automatically on every pull request via GitHub Actions. All tests must pass before merging.

## Code Quality

We use standard Rails tooling for quality and security:

```bash
bundle exec rubocop       # Linting
bundle exec brakeman      # Security scanning
```

## Building Docker Image Locally

If you want to build the Docker image yourself instead of pulling from GHCR:

```bash
docker build -t foresight .
docker run -d -p 3000:80 -v foresight_data:/rails/storage foresight
```

## Git Workflow

For information on commits, pull requests, and merges, see [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md).

**Note**: Git operations (commits, PRs) should only be performed when explicitly requested, not automatically after making code changes.
