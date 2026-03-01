# Foresight

A personal cash flow projection app that helps you see your future account balances based on recurring income and expenses.

**Note:** This is a personal project I maintain for my own use, shared in case others find it useful. See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## Features

- 🔮 **Cash flow projection** - See projected balances up to 24 months ahead
- 📊 **Multi-account tracking** - Monitor checking, savings, and credit cards
- 🔄 **Recurring transactions** - Define flexible income and expense rules
- ⚠️ **Low balance warnings** - Get alerts when projections dip below safety thresholds
- 🐋 **Docker-first** - Designed for easy self-hosting

## Quick Start (Docker)

The easiest way to run Foresight is via Docker.

### Run with Docker CLI

```bash
docker run -d \
  --name foresight \
  -p 3000:80 \
  -v foresight_data:/rails/storage \
  ghcr.io/mrecek/foresight:latest
```

Visit `http://localhost:3000` to set up your account.

### Run with Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  foresight:
    image: ghcr.io/mrecek/foresight:latest
    container_name: foresight
    restart: unless-stopped
    ports:
      - "3000:80"
    volumes:
      - foresight_data:/rails/storage
    environment:
      - SECRET_KEY_BASE=your_generated_secret_key_here # Optional but recommended
      - TZ=America/Los_Angeles # Set your timezone

volumes:
  foresight_data:
```

Run it:
```bash
docker compose up -d
```

## Configuration

You can configure the application using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTH_USERNAME` | Override the database-stored username | *(Database)* |
| `AUTH_PASSWORD` | Override the database-stored password | *(Database)* |
| `SECRET_KEY_BASE` | Session encryption key | *(Baked in image)* |
| `TZ` | Timezone (e.g., `America/New_York`) | `UTC` |
| `RAILS_LOG_LEVEL` | Logging verbosity | `info` |

## Deployment

Foresight runs on HTTP by default. For production self-hosting, it's recommended to put the app behind a reverse proxy that handles HTTPS, such as:

- **[Caddy](https://caddyserver.com/)**
- **[Traefik](https://traefik.io/)**
- **[Nginx Proxy Manager](https://nginxproxymanager.com/)**
- **[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)**

## Built-in Agent Skills

This repo includes two built-in cross-agent skills under `.agents/skills/`:

- `foresight-dev` for local setup, runtime, demo/test mode, and validation workflows
- `foresight-git-workflow` for explicit-request-only git operations and CI/CD workflow guidance

The canonical skill definitions live at:

- `.agents/skills/foresight-dev/SKILL.md`
- `.agents/skills/foresight-git-workflow/SKILL.md`

## Development

Want to build from source or contribute?

```bash
bundle install
bin/rails db:setup
bin/dev
```

For an easier local testing flow, seed demo data and run in test mode:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
TEST_MODE=true bin/dev
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution expectations and the local validation workflow.

## License

MIT
