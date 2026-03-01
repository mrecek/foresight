# Local Setup

Use this reference when you need to bootstrap or run Foresight locally.

## Requirements

- Ruby 3.4+
- SQLite 3
- Node.js for asset compilation, or an environment that supports `tailwindcss-ruby`

## Standard Setup

```bash
git clone https://github.com/mrecek/foresight.git
cd foresight
bundle install
bin/rails db:setup
bin/dev
```

Visit `http://localhost:3000`.

## Useful Variants

- Run the Rails server directly: `bin/rails server`
- Run the Tailwind watcher directly: `bin/rails tailwindcss:watch`
- Apply pending migrations: `bin/rails db:migrate`

## Local Docker Build

Use this only when you specifically need to validate the container image locally.

```bash
docker build -t foresight .
docker run -d -p 3000:80 -v foresight_data:/rails/storage foresight
```
