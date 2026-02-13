# Tasks: Kamal Deployment Configuration

**Card:** #164

## Task 1: Rewrite `config/deploy.yml`

- [x] Replace the default deploy.yml with the full Kamal configuration
- [x] Set service name, image, ssh config, server host with volume
- [x] Configure proxy with host `recuerd0.ai`, SSL, healthcheck
- [x] Configure registry (ghcr.io)
- [x] Set env.secret: `SECRET_KEY_BASE`, `SMTP_USER_NAME`, `SMTP_PASSWORD`, `SMTP_ADDRESS`, `MULTI_TENANT_ENABLED`, `APP_HOST`
- [x] Set env.clear: `RAILS_SERVE_STATIC_FILES`, `SOLID_QUEUE_IN_PUMA`
- [x] Remove `RAILS_MASTER_KEY` from env.secret
- [x] Configure volumes, asset_path, builder, aliases
- [x] Add Litestream db-backup accessory with secret env vars and file mount

## Task 2: Rewrite `.kamal/secrets`

- [x] Remove `RAILS_MASTER_KEY` sourcing
- [x] Add `SECRET_KEY_BASE` from environment
- [x] Add SMTP variables (`SMTP_USER_NAME`, `SMTP_PASSWORD`, `SMTP_ADDRESS`) from environment
- [x] Add Litestream variables (`LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`) from environment
- [x] Add `MULTI_TENANT_ENABLED` from environment
- [x] Add `APP_HOST` from environment
- [x] Keep explanatory comments

## Task 3: Configure production SMTP via ENV

- [x] Uncomment and update `action_mailer.smtp_settings` in `config/environments/production.rb`
- [x] Use `ENV["SMTP_USER_NAME"]`, `ENV["SMTP_PASSWORD"]`, `ENV.fetch("SMTP_ADDRESS", "smtp.example.com")`
- [x] Enable `raise_delivery_errors = true`
- [x] Set `default_url_options` host to `ENV.fetch("APP_HOST", "recuerd0.ai")`

## Task 4: Create `config/litestream.yml`

- [x] Create Litestream replication config for the primary database only (`storage/production.sqlite3`)
- [x] Solid databases (cache, queue, cable) are ephemeral — do not replicate
- [x] Use environment variables for S3 credentials
- [x] Set appropriate bucket placeholder

## Task 5: Dockerfile cleanup

- [x] Update the comment referencing `RAILS_MASTER_KEY` to `SECRET_KEY_BASE`

## Task 6: Verify

- [x] Run `bin/rails test` to ensure no breakage — 338 tests, 931 assertions, 0 failures
- [x] Run `bin/rubocop` on changed files — no offenses
- [x] Verify `config/deploy.yml` is valid YAML
