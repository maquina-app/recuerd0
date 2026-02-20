# recuerd0

LLM context management. Preserve, version, and organize knowledge from AI conversations.

Hosted version available at [recuerd0.ai](https://recuerd0.ai).

## What is recuerd0?

recuerd0 is a self-hostable web application for managing knowledge extracted from AI conversations. It stores Markdown memories organized into workspaces, with full-text search, versioning, and a REST API for programmatic access.

Use it to build a persistent knowledge base from your interactions with LLMs -- so context survives across sessions, tools, and models.

## Key Features

- **Workspaces** -- organize memories into collections with archiving and soft delete
- **Memory versioning** -- branch from any version, compare history, consolidate
- **Full-text search** -- FTS5-powered search with support for AND/OR/NOT, phrase matching, and column filters
- **REST API** -- full CRUD with Bearer token authentication and two permission levels (read-only, full-access)
- **Pinning** -- pin frequently accessed workspaces and memories for quick navigation
- **Multi-user accounts** -- invite team members with admin/member roles
- **Single-tenant and multi-tenant modes** -- run privately for yourself or host for multiple accounts

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Ruby 4.0 |
| Framework | Rails 8.1 |
| Database | SQLite (all four: primary, cache, queue, cable) |
| Frontend | Hotwire (Turbo + Stimulus) |
| CSS | Tailwind CSS |
| JS bundling | Importmaps |
| Deployment | Docker + Kamal |

Built following the One Person Framework philosophy: no Node.js, no Redis, no external service dependencies. SQLite handles everything.

## Self-Hosting with Docker

The quickest way to run recuerd0:

```bash
docker volume create recuerd0_storage

docker run -d \
  --name recuerd0 \
  -p 3000:3000 \
  -v recuerd0_storage:/rails/storage \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  ghcr.io/maquina-app/recuerd0:main
```

This starts recuerd0 in single-tenant mode. On first visit, you'll be guided through creating your account.

For full configuration -- SSL, SMTP, multi-tenant mode, Docker Compose, and environment variables -- see [docs/docker-deployment.md](docs/docker-deployment.md).

## Development Setup

Prerequisites: Ruby 4.0

```bash
bin/setup    # Install dependencies, prepare databases
bin/dev      # Start dev server on port 3820 (Rails + Tailwind + Solid Queue)
```

Run the full CI suite before submitting changes:

```bash
bin/ci       # Setup, lint, security audits, tests, seed validation
```

Or run tests individually:

```bash
bin/rails test                          # All tests
bin/rails test test/models/memory_test.rb    # Single file
```

## Documentation

- [Docker Deployment](docs/docker-deployment.md) -- self-hosting configuration and Docker Compose

## License

recuerd0 is released under the [OSaaS License (MIT + No Competing SaaS)](LICENSE).

You are free to use, self-host, fork, and modify the software. The only restriction: you may not use it to offer a commercially competing hosted service. Self-hosting for personal or internal/organizational use is always permitted.

## Credits

Copyright Mario Alberto Chavez Cardenas.

Designed and built with [Maquina](https://maquina.app).
