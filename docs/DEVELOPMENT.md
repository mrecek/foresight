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

## Test Data

To seed the database with sample accounts and transactions for testing:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
```

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

## Maintainer Workflow

This section documents the git workflow for the project maintainer.

### Branch Types

- `feature/` - New capabilities (e.g., `feature/add-login`)
- `fix/` - Bug fixes (e.g., `fix/payment-validation`)
- `chore/` - Maintenance tasks, dependency updates, build config (e.g., `chore/update-rails`)
- `docs/` - Documentation only changes (e.g., `docs/update-readme`)

### Workflow

1.  **Create a Branch**:
    ```bash
    git checkout -b feature/my-new-feature
    ```

2.  **Open a Pull Request**:
    Use the GitHub CLI to open a PR for self-review. This runs CI checks (Brakeman, Rubocop) before merging.
    ```bash
    gh pr create --web
    ```

3.  **Merge**:
    Squash merge to keep the `main` history clean (one commit per feature).
    ```bash
    gh pr merge --squash --delete-branch
    ```
