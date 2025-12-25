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

Before committing, run and ensure these pass with an exit code of 0:

```bash
bundle exec rubocop
bundle exec brakeman
```

**Verification Criteria:**
- **RuboCop**: Must report "no offenses detected".
- **Brakeman**: Must report "0 warnings" and NO "obsolete" ignores in the summary. If you modify a file mentioned in `config/brakeman.ignore` (e.g., controllers with parameter permits), fingerprints may change, requiring an update to the ignore file.

If checks fail or report obsolete ignores, fix them before proceeding.

#### 5. Determine Commit Strategy

Analyze the changes and determine if multiple commits are warranted.

**Split into multiple commits when:**
- Database migrations are present (always separate from application code)
- Work has distinct phases (refactor → feature, infrastructure → integration)
- Changes span multiple application layers with natural boundaries

**Use a single commit when:**
- Changes are tightly coupled with no natural breakpoints
- Bug fix or small enhancement
- Documentation or configuration only

**Human interaction point:** Present the proposed commit strategy to the user:

```
## Proposed Commits

Based on the changes, I recommend **N commits**:

### Commit 1: `type: description`
Files:
- path/to/file1
- path/to/file2

### Commit 2: `type: description`
Files:
- path/to/file3

Does this grouping look right?
```

Guidelines:
- 2-4 commits is typical for a feature; more suggests the PR may be too large
- Each commit should represent a logical unit of work
- Commits don't need to pass linting individually; only the final state must pass

#### 6. Write Commit Message(s)

Generate commit message(s) following the convention above. Analyze the diff to create meaningful titles and bodies that capture intent. For multiple commits, write a message for each.

#### 7. Stage and Commit

**Human interaction point:** Confirm branch name and commit message(s) with the user before committing.

**For a single commit:**
```bash
git add .
git commit -m "<your generated message>"
```

**For multiple commits:**
Stage and commit files in groups according to the approved strategy:
```bash
# Commit 1: migrations
git add db/migrate/
git commit -m "<message for commit 1>"

# Commit 2: application code
git add app/models/ app/controllers/ app/views/
git commit -m "<message for commit 2>"
```
Repeat for each planned commit.

#### 8. Push and Create PR

```bash
git push -u origin HEAD
gh pr create --title "<title>" --body "<body>"
```

The PR body should include:
- Summary of what the PR accomplishes
- Key changes (can mirror commit body)
- Any notable decisions or trade-offs

**Wait for CI:** Before merging, you MUST verify that CI is green.
- Check status: `gh pr checks`
- Or wait for the GitHub Action to complete.
- Do NOT merge a failing PR.

#### 9. Merge

**Human interaction point:** Confirm merge with the user before proceeding. **CI must be passing (green) before this step.**

After CI passes:

```bash
gh pr merge --rebase --delete-branch
```

We use rebase-merge to:
- Preserve individual commits on main (enables `git bisect`, targeted reverts)
- Maintain linear history (easier to read than merge commits)

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
    gh pr merge --rebase --delete-branch
    ```
