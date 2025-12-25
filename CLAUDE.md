# CLAUDE.md

This file provides guidance for AI coding assistants working with this repository.
It applies to any AI agent (Claude, Copilot, Cursor, etc.).

## GitHub Workflow

For commits and pull requests, follow the **AI Agent Workflow** in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md#ai-agent-workflow).

## Build & Development Commands

```bash
# Install dependencies
bundle install

# Setup database (creates and seeds)
bin/rails db:setup

# Start development server (Rails + Tailwind CSS watcher)
bin/dev

# Or run separately:
bin/rails server          # Rails server on port 3000
bin/rails tailwindcss:watch  # Tailwind CSS compilation

# Database
bin/rails db:migrate      # Run pending migrations
bin/rails db:seed         # Seed data (set SEED_DEMO_DATA=true for demo data)

# Test Mode (bypasses authentication - development only)
SEED_DEMO_DATA=true bin/rails db:seed  # Seeds demo data + creates demo/demo1234 credentials
TEST_MODE=true bin/dev                  # Run with auth bypassed (see docs/DEVELOPMENT.md)
pkill -f "bin/dev"                      # IMPORTANT: Stop server when done testing

# Code quality
bundle exec rubocop       # Linting (uses rubocop-rails-omakase)
bundle exec brakeman      # Security scanning
bundle exec bundler-audit # Dependency vulnerability audit

# Docker
docker build -t foresight .
docker run -d -p 3000:80 -v foresight_data:/rails/storage foresight
```

## Architecture Overview

### Core Domain Model

This is a **cash flow projection app** for personal finance. The key concept is projecting future account balances based on recurring income/expenses.

**Models:**
- `Account` - Bank accounts (checking/savings) with current balance and warning threshold
- `RecurringRule` - Defines repeating transactions (income, expense, or transfer between accounts)
- `Transaction` - Individual transactions, either from rules or one-time. Has `estimated` or `actual` status
- `Setting` - Singleton for app config (auth credentials, session timeout, default view months)

**Key relationships:**
- `RecurringRule` auto-generates `Transaction` records for the projection period
- Transfers create linked transaction pairs (debit from source, credit to destination)
- `Account#projected_balance` calculates balance by summing transactions from balance_date forward

### Transaction Generation Flow

`RecurringRule` uses `RecurrenceCalculator` service to generate transaction dates. When a rule is created/updated:
1. `after_create :generate_initial_transactions` creates transactions up to the default projection period
2. `after_update :regenerate_transactions` destroys future estimated transactions and regenerates
3. `extend_projections_to(end_date)` idempotently adds transactions for extended date ranges

### Authentication

Single-user app with two auth modes:
1. **Database auth** - First-run setup wizard at `/setup` stores bcrypt-hashed credentials in `Setting`
2. **Environment auth** - `AUTH_USERNAME` and `AUTH_PASSWORD` env vars override database credentials

Session timeout is configurable via `Setting#session_timeout_minutes`.

### Frontend

- **Hotwire** (Turbo + Stimulus) - No SPA, server-rendered with Turbo Frame updates
- **Tailwind CSS** with custom design system (see `DESIGN_SYSTEM.md`)
- **Custom fonts**: Darker Grotesque (headings), Manrope (body), JetBrains Mono (numbers)
- **Semantic colors**: `primary`, `success`, `warning`, `danger`, `neutral` with full shade scales

### Design System Helpers

Key helpers in `ApplicationHelper`:
- `design_button(text, path, variant:, size:)` - Styled buttons
- `format_money(amount, show_sign:, color:)` - Currency formatting with color coding
- `badge(text, variant:)` - Status badges
- `toggle_switch(form, field)` - Boolean toggle inputs
- `icon_button(icon:, path:, title:)` - Icon action buttons
- `dropdown_menu` / `dropdown_item` - Dropdown menus

### Stimulus Controllers

Located in `app/javascript/controllers/`:
- `conditional_fields` - Show/hide form fields based on selections
- `frequency_fields` - Dynamic frequency option handling
- `smart_amount` - Amount input with sign inference
- `amount_formatter` - Currency formatting
- `dropdown` - Dropdown menu toggle
- `type_selector` - Transaction type selection UI
