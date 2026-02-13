# Spec: Kamal Deployment Configuration

**Card:** #164 — Configure Kamal deployment
**Date:** 2026-02-12

## Goal

Configure Kamal deployment for recuerd0 to a single server using environment-variable-based secrets (no encrypted credentials), SMTP for production email, Litestream for SQLite backup, and multi-tenant mode support.

## Requirements

### R1: Deploy configuration (`config/deploy.yml`)

Rewrite the default `config/deploy.yml` modeled after the reference deploy (haab), adapted for recuerd0:

- **service:** `recuerd0`
- **image:** `maquina-app/recuerd0` (ghcr.io)
- **ssh:** Custom user and port (placeholders for actual values)
- **servers.web:** Single host with persistent volume `recuerd0_storage:/rails/storage`
- **proxy:** SSL via Let's Encrypt, healthcheck at `/up`
- **registry:** ghcr.io with `KAMAL_REGISTRY_PASSWORD`
- **env.secret:** `SECRET_KEY_BASE`, `SMTP_USER_NAME`, `SMTP_PASSWORD`, `SMTP_ADDRESS`, `MULTI_TENANT_ENABLED`, `APP_HOST`
- **env.clear:** `RAILS_SERVE_STATIC_FILES: true`, `SOLID_QUEUE_IN_PUMA: true`
- **volumes:** `recuerd0_storage:/rails/storage`
- **asset_path:** `/rails/public/assets`
- **builder:** `arch: amd64`
- **aliases:** console, shell, logs, dbc (matching reference)
- **accessories.db-backup:** Litestream 0.3 with `LITESTREAM_ACCESS_KEY_ID` and `LITESTREAM_SECRET_ACCESS_KEY`, mounting `config/litestream.yml` and the storage volume

Remove `RAILS_MASTER_KEY` entirely — it is not used.

### R2: Secrets file (`.kamal/secrets`)

Replace the current secrets file:

- Source `KAMAL_REGISTRY_PASSWORD` from environment
- Source `SECRET_KEY_BASE` from environment
- Source `SMTP_USER_NAME`, `SMTP_PASSWORD`, `SMTP_ADDRESS` from environment
- Source `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY` from environment
- Source `MULTI_TENANT_ENABLED` from environment
- Remove `RAILS_MASTER_KEY` line entirely
- Keep comments explaining the file format

### R3: Production SMTP configuration (`config/environments/production.rb`)

Uncomment and modify the SMTP settings to use environment variables instead of Rails credentials:

```ruby
config.action_mailer.raise_delivery_errors = true

config.action_mailer.smtp_settings = {
  user_name: ENV["SMTP_USER_NAME"],
  password: ENV["SMTP_PASSWORD"],
  address: ENV.fetch("SMTP_ADDRESS", "smtp.example.com"),
  port: 587,
  authentication: :plain
}
```

Update `default_url_options` host to use an environment variable:
```ruby
config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "recuerd0.ai") }
```

### R4: Litestream configuration (`config/litestream.yml`)

Create a Litestream config that replicates only the primary SQLite database (Solid databases are ephemeral and don't need backup):

```yaml
dbs:
  - path: /rails/storage/production.sqlite3
    replicas:
      - type: s3
        bucket: maquina-db-backups
        path: recuerd0/production.sqlite3
        endpoint: https://af5aed93a857f9b9d04c87a4a8dd63e4.r2.cloudflarestorage.com
        region: auto
        sync-interval: 60s
        snapshot-interval: 24h
```

Uses Cloudflare R2 (S3-compatible) with the shared `maquina-db-backups` bucket, stored under the `recuerd0/` path. Credentials via `LITESTREAM_ACCESS_KEY_ID` and `LITESTREAM_SECRET_ACCESS_KEY` environment variables.

### R5: Dockerfile cleanup

Update the comment at the top of the Dockerfile that references `RAILS_MASTER_KEY` to reference `SECRET_KEY_BASE` instead, since the app no longer uses encrypted credentials.

### R6: Add `APP_HOST` to deploy secrets

Add `APP_HOST` to the env.secret list in `config/deploy.yml` and to `.kamal/secrets` so the mailer host is configurable per deployment. Default fallback: `recuerd0.ai`.

## Out of Scope

- CI/CD pipeline configuration
- DNS and server provisioning
- Actual secret values
- Multi-server or load balancer setup
- Kamal hooks (post-deploy, pre-build, etc.)
