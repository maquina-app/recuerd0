# Docker Deployment

Recuerd0 provides a pre-built Docker image so you can self-host your own instance without building from source.

The image is available at:

```
ghcr.io/maquina-app/recuerd0:main
```

To run Recuerd0, you need:

- **Docker** (or any OCI-compatible runtime)
- A **persistent volume** for data storage
- A few **environment variables** for configuration

## Mounting a storage volume

Recuerd0 uses SQLite for all data needs. The container stores everything under `/rails/storage`, which holds four SQLite databases (primary, cache, queue, and cable) plus any Active Storage file uploads.

Mount a persistent volume to `/rails/storage` so your data survives container restarts:

```bash
docker volume create recuerd0_storage

docker run -d \
  -v recuerd0_storage:/rails/storage \
  -e SECRET_KEY_BASE=<value> \
  ghcr.io/maquina-app/recuerd0:main
```

> **Note:** The container's entrypoint automatically runs `bin/rails db:prepare` on startup, creating or migrating the databases as needed. You don't need to run any setup commands manually.

## Configuring with environment variables

### Secret key base

`SECRET_KEY_BASE` is **required**. Rails uses it to encrypt sessions, cookies, and other sensitive data.

Generate one with:

```bash
docker run --rm ghcr.io/maquina-app/recuerd0:main bin/rails secret
```

Or if you have a local Rails installation:

```bash
bin/rails secret
```

### SSL

Recuerd0 uses [Thruster](https://github.com/basecamp/thruster) as an HTTP proxy in front of Puma. Thruster handles SSL termination, HTTP/2, caching, and compression automatically.

**Option 1: Automatic SSL with Let's Encrypt**

Set `TLS_DOMAIN` to your domain name. Thruster will obtain and renew certificates automatically. Expose ports 80 and 443:

```bash
docker run -d \
  -p 80:80 -p 443:443 \
  -v recuerd0_storage:/rails/storage \
  -e SECRET_KEY_BASE=<value> \
  -e TLS_DOMAIN=recuerd0.example.com \
  ghcr.io/maquina-app/recuerd0:main
```

**Option 2: No SSL (local or development use)**

Disable SSL and expose only port 80:

```bash
docker run -d \
  -p 80:80 \
  -v recuerd0_storage:/rails/storage \
  -e SECRET_KEY_BASE=<value> \
  -e DISABLE_SSL=true \
  ghcr.io/maquina-app/recuerd0:main
```

**Option 3: Behind an external reverse proxy**

If you already have a reverse proxy (nginx, Caddy, Traefin) handling SSL, just expose port 80 and point your proxy at the container. No `TLS_DOMAIN` or `DISABLE_SSL` needed — Thruster will serve plain HTTP on port 80.

### SMTP email

Recuerd0 sends emails for password resets and other notifications. Configure your SMTP server with these environment variables:

| Variable | Description | Default |
|---|---|---|
| `SMTP_ADDRESS` | SMTP server hostname | `smtp.example.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_AUTHENTICATION` | Authentication method (`plain`, `login`, `cram_md5`) | `plain` |
| `SMTP_USER_NAME` | SMTP username | — |
| `SMTP_PASSWORD` | SMTP password | — |

### Base URL

Set `APP_HOST` to the domain where your instance is accessible. This is used to generate correct URLs in emails (password reset links, etc.):

```
APP_HOST=recuerd0.example.com
```

If not set, it defaults to `recuerd0.ai`.

### Multi-tenant mode

By default, Recuerd0 runs in **single-tenant mode**: no public registration, no marketing pages. On first visit, you'll be guided through creating the initial account. After that, only login is available.

To enable **multi-tenant mode** with public registration:

```
MULTI_TENANT_ENABLED=true
```

> **Note:** Multi-tenant mode is intended for personal or internal use. Recuerd0 is distributed under the [OSaaS License (MIT + No Competing SaaS)](../LICENSE), which prohibits offering the software as a commercially competing hosted service. Please review the license before deploying a multi-tenant instance.

### Background jobs

Recuerd0 uses Solid Queue for background job processing. For single-server deployments, run the queue supervisor inside the Puma web process:

```
SOLID_QUEUE_IN_PUMA=true
```

This is the recommended setting for Docker deployments. Without it, you would need to run a separate Solid Queue process.

## Example docker-compose.yml

```yaml
services:
  recuerd0:
    image: ghcr.io/maquina-app/recuerd0:main
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - recuerd0_storage:/rails/storage
    environment:
      SECRET_KEY_BASE: "replace-with-a-generated-secret"
      TLS_DOMAIN: "recuerd0.example.com"
      APP_HOST: "recuerd0.example.com"
      SMTP_ADDRESS: "smtp.example.com"
      SMTP_USER_NAME: "your-smtp-username"
      SMTP_PASSWORD: "your-smtp-password"
      SOLID_QUEUE_IN_PUMA: "true"
      # MULTI_TENANT_ENABLED: "true"  # Uncomment for public registration
      # DISABLE_SSL: "true"           # Uncomment if not using TLS_DOMAIN

volumes:
  recuerd0_storage:
```

Start with:

```bash
docker compose up -d
```

Visit your domain (or `http://localhost` if running locally with `DISABLE_SSL=true`) to complete the first-run setup.
