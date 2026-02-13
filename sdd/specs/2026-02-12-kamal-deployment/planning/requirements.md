# Requirements: Kamal Deployment

## Context

Recuerd0 is a Rails 8 app deployed via Kamal to a single server. It uses SQLite for all databases (primary, cache, queue, cable), Thruster for HTTP caching/compression, and Solid Queue running in-process via Puma. The app supports two tenancy modes controlled by `MULTI_TENANT_ENABLED` env var.

## Decisions

### No encrypted credentials

The app will NOT use `config/master.key` or `rails credentials:edit`. Instead:
- `SECRET_KEY_BASE` is set as an environment variable via `.kamal/secrets`
- SMTP credentials are set as environment variables via `.kamal/secrets`
- All secrets are plain environment variables injected by Kamal at deploy time

### Secrets (via `.kamal/secrets`)

| Secret | Purpose |
|--------|---------|
| `KAMAL_REGISTRY_PASSWORD` | Container registry authentication (ghcr.io) |
| `SECRET_KEY_BASE` | Rails session signing, message verifiers, etc. |
| `SMTP_USER_NAME` | SMTP authentication for outbound email |
| `SMTP_PASSWORD` | SMTP authentication for outbound email |
| `SMTP_ADDRESS` | SMTP server hostname |
| `LITESTREAM_ACCESS_KEY_ID` | S3-compatible credentials for Litestream backup |
| `LITESTREAM_SECRET_ACCESS_KEY` | S3-compatible credentials for Litestream backup |
| `MULTI_TENANT_ENABLED` | Enable multi-tenant mode (`true` or omit) |

| `APP_HOST` | Application hostname for mailer URLs (default: `recuerd0.ai`) |

### SMTP configuration

Production email uses environment variables instead of Rails credentials:
```ruby
config.action_mailer.smtp_settings = {
  user_name: ENV["SMTP_USER_NAME"],
  password: ENV["SMTP_PASSWORD"],
  address: ENV.fetch("SMTP_ADDRESS", "smtp.example.com"),
  port: 587,
  authentication: :plain
}
```

### Infrastructure (from reference deploy)

| Setting | Value |
|---------|-------|
| SSH user | Custom (non-root) |
| SSH port | Custom |
| Registry | ghcr.io |
| Proxy/SSL | Let's Encrypt via Thruster |
| Volume | Persistent named volume for `/rails/storage` |
| Builder | amd64 architecture |
| Accessory | Litestream 0.3 for SQLite replication to S3 |
| Asset bridging | `/rails/public/assets` |

### Environment variables (clear)

| Variable | Value | Purpose |
|----------|-------|---------|
| `RAILS_SERVE_STATIC_FILES` | `true` | Serve assets from Rails |
| `SOLID_QUEUE_IN_PUMA` | `true` | Run Solid Queue in-process |

### Environment variables (secret)

| Variable | Purpose |
|----------|---------|
| `SECRET_KEY_BASE` | Rails key base (replaces RAILS_MASTER_KEY) |
| `SMTP_USER_NAME` | SMTP auth |
| `SMTP_PASSWORD` | SMTP auth |
| `SMTP_ADDRESS` | SMTP server |
| `MULTI_TENANT_ENABLED` | Tenancy mode |

## Files to create/modify

1. `config/deploy.yml` — Full Kamal deploy configuration
2. `.kamal/secrets` — Secret sourcing (from env vars, not 1password)
3. `config/environments/production.rb` — SMTP via ENV, mailer host
4. `config/litestream.yml` — Litestream replication config for SQLite databases
5. `Dockerfile` — Remove RAILS_MASTER_KEY reference from comment

## Out of scope

- CI/CD pipeline setup
- DNS configuration
- Server provisioning
- Actual secret values
- Multiple web server / load balancer setup
