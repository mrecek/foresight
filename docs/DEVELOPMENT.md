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

This section documents the git workflow for the project maintainer. It includes both an AI-assisted workflow (for AI coding agents) and an interactive workflow (for humans).

### Branch Types

- `feature/` - New capabilities (e.g., `feature/mobile-navigation`)
- `fix/` - Bug fixes (e.g., `fix/session-timeout`)
- `chore/` - Maintenance tasks, dependency updates, build config (e.g., `chore/update-rails`)
- `docs/` - Documentation only changes (e.g., `docs/update-readme`)

### Commit Message Convention

Use this format for all commits:

```
<type>: <imperative summary under 72 chars>

- Key change 1
- Key change 2
- Key change 3
```

**Guidelines:**
- Title describes WHAT changed and WHY (not just "update files")
- Use imperative mood: "Add", "Fix", "Refactor" (not "Added", "Fixed")
- Body bullets highlight significant changes, not every file touched
- Focus on intent and impact, not mechanics

**Examples:**

```
feat: Add responsive mobile navigation menu

- Create mobile_menu_controller.js Stimulus controller
- Update application layout with hamburger toggle
- Refine CSS for mobile breakpoints
```

```
fix: Correct session timeout calculation

- Fix off-by-one error in timeout check
- Add regression test for edge case
```

---

### AI Agent Workflow

This workflow is designed for AI coding assistants. Follow each step in order.

#### 1. Analyze Changes

Run `git status` and `git diff` to understand:
- What files changed
- The nature of the changes (new feature, bug fix, maintenance, docs)
- The primary scope or component affected

#### 2. Determine Branch Type

Based on your analysis, choose the appropriate prefix:
- `feature/` - New capabilities or enhancements
- `fix/` - Bug fixes
- `chore/` - Maintenance, dependencies, build config
- `docs/` - Documentation-only changes

#### 3. Create Branch

Format: `<type>/<short-kebab-description>`
- Use 2-4 words maximum
- Describe the primary change, not individual files

```bash
git checkout -b feature/my-feature-name
```

#### 4. Run Quality Checks (Required)

Before committing, run and ensure these pass:

```bash
bundle exec rubocop
bundle exec brakeman
```

If checks fail, fix issues before proceeding.

#### 5. Write Commit Message

Generate a commit message following the convention above. Analyze the diff to create a meaningful title and body that captures intent.

#### 6. Stage and Commit

**Human interaction point:** Confirm branch name and commit message with the user before committing.

```bash
git add .
git commit -m "<your generated message>"
```

#### 7. Push and Create PR

```bash
git push -u origin HEAD
gh pr create --title "<title>" --body "<body>"
```

The PR body should include:
- Summary of what the PR accomplishes
- Key changes (can mirror commit body)
- Any notable decisions or trade-offs

#### 8. Merge

**Human interaction point:** Confirm merge with the user before proceeding.

After CI passes:

```bash
gh pr merge --squash --delete-branch
```

---

### Interactive Workflow (for Humans)

For manual, interactive PR creation:

1.  **Create a branch:**
    ```bash
    git checkout -b feature/my-new-feature
    ```

2.  **Run quality checks:**
    ```bash
    bundle exec rubocop && bundle exec brakeman
    ```

3.  **Commit your changes** following the commit message convention above.

4.  **Open a Pull Request** (opens browser for review):
    ```bash
    git push -u origin HEAD
    gh pr create --web
    ```

5.  **Merge** after CI passes:
    ```bash
    gh pr merge --squash --delete-branch
    ```
