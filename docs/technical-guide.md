# Recuerd0 Technical Guide

## Overview

Recuerd0 is a personal knowledge management application built with Rails 8, Hotwire, and SQLite. Users organize markdown-formatted memories into workspaces, with support for versioning, pinning, archiving, and soft deletion. The application follows the One Person Framework philosophy: SQLite for all data storage, Solid libraries instead of Redis, Kamal for deployment, and zero JavaScript build tooling.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Ruby 4.0.0 |
| Framework | Rails 8.1.2 |
| Database | SQLite 3 (via sqlite3 gem 2.1+) |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS 4 |
| Asset pipeline | Propshaft + Importmaps (no Node.js) |
| UI components | maquina-components gem |
| Markdown | Commonmarker (CommonMark spec) |
| Pagination | Pagy 9.x |
| Authentication | Rails 8 built-in (bcrypt + sessions) |
| Background jobs | Solid Queue (SQLite-backed) |
| Caching | Solid Cache (SQLite-backed) |
| WebSockets | Solid Cable (SQLite-backed) |
| Deployment | Kamal 2.x + Docker + Thruster |
| Linting | Standard Ruby (via RuboCop, `bin/rubocop`) |
| CI | `bin/ci` — Rails 8.1 `ActiveSupport::ContinuousIntegration` |
| Testing | Minitest + Capybara + Selenium |

## Domain Model

```
Account
 ├── has_many :users           (account members, max 5 active)
 ├── has_many :workspaces      (owned workspaces)
 ├── concerns: SoftDeletable   (30-day retention)
 ├── validates :name presence
 ├── generate_invitation_token (MessageVerifier, 7-day expiry)
 └── anonymize_users!          (email anonymization on delete)

User
 ├── belongs_to :account       (required)
 ├── has_many :sessions        (auth sessions)
 ├── has_many :access_tokens   (API tokens)
 ├── has_many :pins            (polymorphic bookmarks)
 ├── has_many :pinned_workspaces  (through pins, active only)
 ├── has_many :pinned_memories    (through pins)
 ├── role: admin | member      (first user is admin)
 ├── scope :active             (excludes anonymized emails)
 └── anonymize_email!          (replaces with deleted-<hex>@domain)

AccessToken
 ├── belongs_to :user
 ├── permission: read_only | full_access
 ├── token_digest (SHA256 hashed)
 └── last_used_at (touched on each API request)

Workspace
 ├── belongs_to :account
 ├── has_many :memories        (counter cached)
 ├── concerns: SoftDeletable, Archivable, Pinnable
 └── state hierarchy: active → archived → deleted

Memory
 ├── belongs_to :workspace     (touch: true, counter_cache: true)
 ├── belongs_to :parent_memory (optional, for versioning)
 ├── has_one :content
 ├── has_many :child_versions
 ├── concerns: Pinnable, Versionable, Searchable
 └── serializes :tags as JSON Array

Content
 ├── belongs_to :memory        (touch: true)
 ├── stores :body (markdown text)
 └── after_save_commit: triggers search reindex on parent memory

Pin
 ├── belongs_to :user
 ├── belongs_to :pinnable      (polymorphic: Workspace or Memory)
 └── position-ordered, max 10 per user
```

### Tenancy Modes

The application supports two tenancy modes controlled by the `MULTI_TENANT_ENABLED` environment variable (default: `false`):

**Single-tenant mode** (default):
- No public registration — account creation only via first run setup
- Marketing pages (landing, terms, privacy, api-docs, cli, agents) disabled
- `FirstRunController` forces account creation on first visit when no accounts exist
- Root route points to `workspaces#index` (requires authentication)
- Login page hides sign-up link and terms/privacy footer
- Invitations still available (admin can invite team members)

**Multi-tenant mode** (`MULTI_TENANT_ENABLED=true`):
- Public registration, marketing pages, and full landing page enabled
- Root route points to `home#index` (landing page for visitors, redirects authenticated users to workspaces)

Configuration: `Rails.application.config.multi_tenant` (boolean). Helper: `multi_tenant?` available in all controllers and views.

### Multi-Tenancy Data Model

Account serves as the multi-tenant container. Each user belongs to exactly one account, and workspaces belong to accounts (not users directly).

- `Current.account` — derived from `Current.user.account`, available throughout the request
- All workspace queries scope to `Current.account.workspaces`
- Pins remain user-scoped (within account context)
- Sessions remain user-scoped (authentication is user-level)

### User Roles & Account Management

Users have a `role` field: `admin` or `member`. The first user created with an account is always admin.

- **Admin**: can edit account name, manage users, generate invitations, delete account
- **Member**: read-only view of account details and user list

**Invitation flow**: Admin generates a signed token (`Rails.application.message_verifier(:account_invitations)`, 7-day expiry). The token encodes the account ID. Recipients visit the invitation URL, create an account (as member role), and are auto-logged-in.

**Account deletion**: Soft-deletes the account, anonymizes all user emails (replaces with `deleted-<hex>@domain`), destroys all sessions. Deleted accounts are blocked at the authentication layer. 30-day retention before permanent deletion.

**User removal**: Admin anonymizes a user's email and destroys their sessions. Cannot remove self or other admins.

### Key Model Behaviors

**Workspace states** follow a one-way hierarchy. Active workspaces can be archived or deleted. Archived workspaces can be unarchived (back to active) or deleted. Deleted workspaces have a 30-day retention window before permanent deletion. State changes automatically unpin the workspace.

**Memory versioning** uses a flat branching model. All versions share a common root parent. Any version can spawn a new version (not just the latest). `consolidate_versions!` collapses history by keeping one version and destroying the rest.

**Pinning** is polymorphic with a 10-pin user limit. Pins have position ordering that auto-reorders on removal. Only active items can be pinned.

**Touch propagation** flows upward: Content touches Memory, Memory touches Workspace. This keeps `updated_at` timestamps current at every level.

## Model Concerns

### SoftDeletable (`app/models/concerns/soft_deletable.rb`)

Adds `deleted_at` column with a default scope excluding deleted records.

- `soft_delete` / `restore` / `destroy!` (permanent)
- `deleted` / `with_deleted` / `not_deleted` scopes
- `days_until_permanent_deletion` (30-day retention)
- Overrides `destroy` to perform soft delete; use `destroy!` for permanent deletion

### Archivable (`app/models/concerns/archivable.rb`)

Adds `archived_at` column.

- `archive` / `unarchive` / `toggle_archive`
- `archived` / `not_archived` scopes

### Pinnable (`app/models/concerns/pinnable.rb`)

Adds polymorphic `has_many :pins`.

- `pin!(user)` / `unpin!(user)` / `toggle_pin_for!(user)`
- `pinned_by?(user)` / `pin_position_for(user)`
- `pinned_by(user)` / `not_pinned_by(user)` scopes
- Validates `active?` before pinning (if the method exists)

### Versionable (`app/models/concerns/versionable.rb`)

Adds `version` (integer) and `parent_memory_id` (self-referential FK).

- `next_version_number` / `version_label` (e.g., "v3")
- `has_versions?` / `consolidate_versions!`
- Auto-sets version number on create

### Searchable (`app/models/concerns/searchable.rb`)

FTS5 full-text search backed by the `memories_search` virtual table (trigram tokenizer).

- `full_search(query)` scope — wraps query as a quoted FTS5 phrase (neutralizes special syntax). Used by HTML search for safe browser input. Returns `none` for queries shorter than 3 characters.
- `api_search(query)` scope — passes raw FTS5 query with full operator support: AND, OR, NOT, `"phrase"`, `title:term`, `body:term`, `(grouping)`. Used by JSON API search. FTS5 syntax errors surface as `ActiveRecord::StatementInvalid` (not `SQLite3::SQLException` directly).
- `rebuild_search_index` — public method to manually reindex a memory.
- `update_search_index` (private, `after_save_commit`) — resolves the root memory, finds the newest version (highest `version` among children, or root itself), and indexes that version's title and body under the root's ID. This ensures `full_search` returns root memories compatible with the `latest_versions` scope.
- `delete_search_index` (private, `after_destroy_commit`) — deletes the FTS entry by root ID.
- Content changes trigger reindexing via `Content#reindex_memory` (`after_save_commit`).
- Bulk reindex: `bin/rails search:reindex`

## Rich Model Methods

Multi-model operations are handled by model methods wrapped in transactions:

| Method | Purpose |
|--------|---------|
| `Account.create_with_user(email:, password:, password_confirmation:)` | Creates Account + User atomically. Returns user on success, invalid user with errors on failure. |
| `Memory.create_with_content(workspace, attrs)` | Builds Memory + Content in a transaction. Accepts title, tags, source, content. |
| `memory.update_with_content(attrs)` | Updates Memory attributes and Content body atomically. |
| `memory.create_version!(attrs)` | Branches a new version from any existing version. Copies attributes from original, resolves root parent. |

## Controllers

### Main Controllers

| Controller | Responsibilities |
|-----------|-----------------|
| `WorkspacesController` | CRUD for workspaces. `show` auto-redirects to archived/deleted namespaced routes based on state. Paginated index with pins-first ordering. |
| `MemoriesController` | CRUD for memories (via use cases). Includes `preview` action for markdown rendering in a Turbo Frame. |
| `PinsController` | Create/destroy pins. Validates pinnable type against whitelist. Enforces 10-pin limit. |
| `HomeController` | Public landing page (multi-tenant only). Redirects authenticated users to workspaces. |
| `SessionsController` | Login/logout. Redirects authenticated users away from login form. Rate-limited to 10 attempts per 3 minutes. |
| `RegistrationsController` | Self-service user signup (multi-tenant only). Redirects authenticated users away from signup form. Creates Account + User atomically. Rate-limited to 10 attempts per hour. |
| `FirstRunController` | Single-tenant first run setup. Creates initial account when no accounts exist. Guards: `require_single_tenant_mode`, `require_no_accounts`. |
| `PasswordsController` | Token-based password reset via email. Anti-enumeration (always shows success). |
| `SearchController` | Cross-workspace memory search. HTML uses `full_search` (phrase-quoted). JSON API uses `api_search` (raw FTS5 operators). Validates query presence/length for API, rescues FTS5 syntax errors. Optional `workspace_id` filter. |

### Namespaced Controllers

| Controller | Purpose |
|-----------|---------|
| `Workspaces::ArchivesController` | List/show archived workspaces, archive/unarchive actions. |
| `Workspaces::DeletedController` | List/show deleted workspaces, restore/permanent-delete actions. |
| `Memories::VersionsController` | List/show/create versions. `destroy` consolidates (keeps one, removes others). |
| `AccountsController` | Show/update/destroy account. Admin-only for update/destroy. |
| `Account::UsersController` | Admin-only user removal via email anonymization. |
| `Account::InvitationsController` | Admin-only invitation link generation with user limit check. |
| `InvitationsController` | Public invitation acceptance. Security layout, rate-limited. |

### Controller Concerns

- **Authentication** (`app/controllers/concerns/authentication.rb`) - `before_action :require_authentication` by default. Opt-out with `allow_unauthenticated_access`. Opt-in to `before_action :redirect_authenticated_user` to bounce logged-in users to `workspaces_path` (used by SessionsController, RegistrationsController, HomeController). Note: `redirect_authenticated_user` calls `resume_session` internally because `allow_unauthenticated_access` skips `require_authentication`, which is what normally resolves the session. Session stored in signed permanent cookie (httponly, same_site: lax). Also handles Bearer token authentication for API requests. Blocks deleted accounts (session redirect + API 401).
- **AdminAuthorizable** (`app/controllers/concerns/admin_authorizable.rb`) - `require_admin` method redirects non-admin users to `account_path`. Shared by account management controllers.
- **WorkspaceScoped** (`app/controllers/concerns/workspace_scoped.rb`) - Loads workspace with `with_deleted` scope for namespaced controllers. Includes `require_active_workspace` with HTML/JSON format support.
- **ApiHelpers** (`app/controllers/concerns/api_helpers.rb`) - JSON API utilities: pagination headers (`X-Page`, `X-Per-Page`, `X-Total`, `X-Total-Pages`, `Link`), error response helpers (`render_validation_errors`, `render_not_found`, `render_unauthorized`, `render_forbidden`, `render_rate_limited`).
## Routing Structure

```
Root:       GET / → home#index (multi-tenant) or workspaces#index (single-tenant)
Auth:       resource  :session                   → sessions (login/logout)
            resource  :registration              → registrations (multi-tenant only)
            resource  :first_run                 → first_run (always routable, controller-guarded)
            resources :passwords, param: :token  → passwords (reset flow)

Workspaces: resources :workspaces do
              resources :memories do
                collection { post :preview }      → memories#preview
                resources :versions               → memories/versions (index,show,create,destroy)
              end
              collection { get :archived, :deleted }
              member     { post/delete :archive }
            end

            Scoped: GET/POST/DELETE workspaces/archived/:id
                    GET/POST/DELETE workspaces/deleted/:id

Account:    resource  :account (show, update, destroy)
              resources :users, controller: account/users (destroy)
              resource  :invitation, controller: account/invitations (create)
            resources :invitations, param: :token (show, create — public)

Search:     GET /search(.json)                  → search#index (HTML + JSON API)

Pins:       POST/DELETE pins/:pinnable_type/:pinnable_id → pins (polymorphic)

Health:     GET /up → rails/health#show

API:        All routes accept .json format for JSON API access
            Authentication via Bearer token in Authorization header
            Rate limited: 100 requests/minute per token
```

## REST API

JSON API for programmatic access to workspaces and memories. Full documentation in `docs/API.md`.

### Authentication

All API requests require Bearer token authentication:

```
Authorization: Bearer <token>
```

**Token permissions**:
- `read_only` — GET endpoints only
- `full_access` — all CRUD operations (GET, POST, PATCH, DELETE)

Tokens are created via `AccessToken.create(user: user, permission: "full_access")`. The raw token is only available immediately after creation via `access_token.raw_token`.

### Rate Limiting

100 requests per minute per token, enforced via Rails 8 `rate_limit`. Exceeded requests receive `429 Too Many Requests` with `Retry-After: 60` header.

### Endpoints

| Method | Endpoint | Permission | Description |
|--------|----------|------------|-------------|
| GET | `/workspaces.json` | read_only | List workspaces (paginated) |
| GET | `/workspaces/:id.json` | read_only | Show workspace |
| POST | `/workspaces.json` | full_access | Create workspace |
| PATCH | `/workspaces/:id.json` | full_access | Update workspace |
| POST | `/workspaces/:id/archive.json` | full_access | Archive workspace |
| DELETE | `/workspaces/:id/archive.json` | full_access | Unarchive workspace |
| GET | `/workspaces/:id/memories.json` | read_only | List memories (paginated) |
| GET | `/workspaces/:id/memories/:id.json` | read_only | Show memory with content |
| POST | `/workspaces/:id/memories.json` | full_access | Create memory |
| PATCH | `/workspaces/:id/memories/:id.json` | full_access | Update memory |
| DELETE | `/workspaces/:id/memories/:id.json` | full_access | Delete memory |
| POST | `/workspaces/:id/memories/:id/versions.json` | full_access | Create new version |
| GET | `/search.json?q=<query>` | read_only | Full-text search across memories (FTS5 operators: AND, OR, NOT, phrase, column filters) |

### Pagination Headers

List endpoints return pagination metadata in response headers:

| Header | Description |
|--------|-------------|
| `X-Page` | Current page number |
| `X-Per-Page` | Items per page |
| `X-Total` | Total item count |
| `X-Total-Pages` | Total pages |
| `Link` | RFC 5988 pagination links (first, prev, next, last) |

### Error Responses

All errors follow a consistent JSON structure:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found",
    "status": 404
  }
}
```

**Error codes**: `UNAUTHORIZED` (401), `FORBIDDEN` (403), `NOT_FOUND` (404), `VALIDATION_ERROR` (422), `RATE_LIMITED` (429)
```

## Authentication

Rails 8 built-in authentication with `has_secure_password` (bcrypt).

- **Session model**: stores user_id, ip_address, user_agent in database
- **Current context**: `Current.session` / `Current.user` / `Current.account` via `ActiveSupport::CurrentAttributes`
- **Cookie**: signed, permanent, httponly, same_site: lax (key: `:session_id`)
- **Registration**: self-service signup creates Account + User atomically, auto-login after success (multi-tenant only)
- **First run**: in single-tenant mode, unauthenticated requests redirect to `/first_run/new` when no accounts exist; once an account is created, redirects to login
- **Password reset**: encrypted token via Rails message verifier, delivered by `PasswordsMailer`
- **Authenticated user redirect**: `redirect_authenticated_user` before_action bounces logged-in users from auth pages (login, signup, landing) to `workspaces_path`
- **Rate limiting**: 10 login attempts per 3 minutes, 10 registration attempts per hour

## Frontend Architecture

### Layouts

- **application** - Main layout with sidebar, toaster, confirm dialog. Uses `turbo_refresh_method_tag :morph`.
- **security** - Centered card layout for login/password pages. Auto-dismiss flash alerts.

### Stimulus Controllers

| Controller | Purpose | Teardown |
|-----------|---------|----------|
| `markdown-editor` | Write/Preview tab switching for memory editor. Submits hidden form to preview endpoint, updates Turbo Frame. | Resets to Write mode |
| `tag-input` | Add/remove tags with Enter, comma, or Backspace. Renders badge-style chips. Generates hidden inputs for form submission. | N/A |
| `details` | Closes `<details>` elements on outside click. 100ms delay prevents immediate close. | N/A |
| `scroll-to-top` | FAB appears at 300px scroll. Smooth scroll back to top. Works with `<main>` or window. | Hides button |
| `navigate` | Navigates on `<select>` change via `Turbo.visit`. | N/A |
| `clipboard` | Copy text to clipboard via `navigator.clipboard.writeText()`. Toggles copy/check icons for 2s feedback. | Clears timeout, resets icons |

### Turbo / Hotwire Patterns

> See `docs/hotwire-patterns.md` for the full Hotwire reference with event lifecycle, data attributes, and Stimulus controller details.

- **Morph mode**: `turbo_refresh_method_tag :morph` + `turbo_refresh_scroll_tag :preserve` enables smooth page morphing with scroll preservation
- **Form submissions with morph**: Use standard `redirect_to` (303 See Other) after successful form submissions. Turbo Drive follows the redirect, and because the morph meta tag is present, it morphs only the changed DOM elements instead of replacing the entire body. This is the canonical Turbo 8 pattern. **Do NOT use `turbo_stream.refresh` for form responses** — it is designed for WebSocket broadcasting and will be silently ignored due to request_id deduplication when used as a direct form response.
- **Stateful cleanup**: `turbo:before-cache` cleans live DOM; `turbo:before-render` cleans incoming body on Back/Forward
- **Global teardown**: `application.js` calls `teardown()` on all Stimulus controllers that implement it (Better Stimulus pattern)
- **Manual dropdown cleanup**: `application.js` handles gem-provided dropdown menus until the gem adds its own teardown
- **Custom confirm dialog**: Overrides `Turbo.config.forms.confirm` with a styled `<dialog>` element returning a Promise

### maquina-components Gem

UI component library providing partials, Stimulus controllers, and CSS. Components are rendered via `render "components/..."` and styled with `data-component` attribute selectors.

**Helpers included** (via `MaquinaComponentsHelper`):
- `IconsHelper` - `icon_for(:name)` with app-level SVG fallbacks
- `PaginationHelper` - `pagination_nav(pagy, :route_helper, params: {})`
- `BreadcrumbsHelper` - `breadcrumbs(links_hash, current_page)`
- `ToastHelper` - `toast_flash_messages`, `toast_success`, `toast_error`, etc.

**Component variants**:

| Component | Variants |
|-----------|----------|
| alert | `:default`, `:destructive`, `:success`, `:warning` |
| badge | `:default`, `:secondary`, `:destructive`, `:warning`, `:outline` |
| empty | `:default`, `:outline` |
| toast | `:default`, `:success`, `:info`, `:warning`, `:error` |

**Form data attributes**:

| Attribute | CSS Effect |
|-----------|-----------|
| `data-component="form"` | `grid gap-6` (omit for custom layouts) |
| `data-form-part="group"` | `grid gap-2` (8px between label/input/error) |
| `data-form-part="error"` | `text-sm font-medium` + destructive color |
| `data-component="label"` | `text-sm font-medium leading-none select-none` |
| `data-component="input"` | `h-9 rounded-md border shadow-xs` + focus ring |
| `data-component="textarea"` | Same as input, auto-height |
| `data-component="button"` | Styled button with variant/size support |

**Focus ring pattern** (from gem CSS):
```css
/* Base */
border-color: var(--input);
box-shadow: var(--shadow-xs, 0 1px 2px 0 rgb(0 0 0 / 0.05));

/* Focus */
border-color: var(--ring);
box-shadow: var(--shadow-xs), 0 0 0 3px color-mix(in oklch, var(--ring) 50%, transparent);
```

### CSS Theme

Defined in `app/assets/tailwind/application.css` using oklch color space. Primary hue is 150 (green). Full dark mode support via `.dark` class.

Key variables: `--primary`, `--secondary`, `--destructive`, `--success`, `--warning`, `--info` (each with `-foreground` variant).

### Typography

Three self-hosted font families in `app/assets/fonts/` (woff2), declared in `app/assets/tailwind/fonts.css`:

- `font-sans` → Instrument Sans 400 (body text)
- `font-mono` → Geist Mono 400 (code, metadata)
- `font-display` → Jura 400/500 (headings, navigation, brand)

Headings use `font-display font-medium` (Jura 500). Body text uses `font-sans` (default).

**Propshaft font paths:** Files in `app/assets/fonts/` are served at the root URL (e.g., `/jura-v34-latin-regular.woff2`). Use `url('/filename.woff2')` in CSS — not relative paths or `/assets/` prefix.

Custom overrides:
- `.tag-input-container` - Mirrors gem's input focus ring for the tag input component
- `.editor-textarea` - Removes border/shadow/radius for flush textarea inside editor container

## Database

### Schema

SQLite with 8 tables: `accounts`, `users`, `sessions`, `access_tokens`, `workspaces`, `memories`, `contents`, `pins`. Plus one FTS5 virtual table: `memories_search` (trigram tokenizer, columns: `title`, `body`, `memory_id UNINDEXED`).

**Notable indexes**:
- `users.email_address` (unique)
- `users.account_id` (foreign key to accounts)
- `users.role` (for role-based queries)
- `accounts.deleted_at` (for soft delete filtering)
- `access_tokens.token_digest` (unique, for token lookup)
- `access_tokens.user_id` (foreign key to users)
- `workspaces.account_id` (foreign key to accounts)
- `memories(parent_memory_id, version)` (composite, for version lookups)
- `pins(user_id, pinnable_type, pinnable_id)` (unique, prevents duplicate pins)
- `pins(user_id, pinnable_type, position)` (composite, for ordered pin lists)

**Production multi-database** (config/database.yml):
- Primary: `storage/production.sqlite3`
- Cache: `storage/production_cache.sqlite3` (Solid Cache)
- Queue: `storage/production_queue.sqlite3` (Solid Queue)
- Cable: `storage/production_cable.sqlite3` (Solid Cable)

### Migration Timeline

1. **2025-06-12**: Users, sessions, workspaces (initial auth + domain)
2. **2025-07-11**: Memories, contents (core feature)
3. **2025-07-12**: Soft delete + archive columns on workspaces
4. **2025-07-14**: Counter cache (`memories_count` on workspaces)
5. **2025-07-27**: Pins (polymorphic with position ordering)
6. **2025-09-30**: Versioning (`version` + `parent_memory_id` on memories)
7. **2026-02-04**: Full-text search (`memories_search` FTS5 virtual table with trigram tokenizer)
8. **2026-02-05**: Accounts (multi-tenancy container), user.account_id, workspace.account_id (replaces user_id)
9. **2026-02-05**: Access tokens (API authentication with read_only/full_access permissions)
10. **2026-02-05**: User roles (`role` column: admin/member) and account soft delete (`deleted_at` on accounts)

## Deployment

### Docker

Multi-stage Dockerfile: Ruby 4.0.0-slim base, jemalloc for memory optimization, Thruster for HTTP acceleration. Runs as non-root `rails` user (UID 1000). Entrypoint auto-runs `db:prepare` on server start.

### Kamal

Configured in `config/deploy.yml`. Single-server deployment with:
- Let's Encrypt SSL via Kamal proxy
- Persistent volume at `/rails/storage` for SQLite databases
- `SOLID_QUEUE_IN_PUMA=true` runs jobs in-process (no separate worker)
- `MULTI_TENANT_ENABLED=true` to enable public registration and marketing pages (default: single-tenant)
- Secrets: `RAILS_MASTER_KEY` from `config/master.key`, registry password from environment

### CI/CD

**Local CI** (`bin/ci`): Rails 8.1 introduces `ActiveSupport::ContinuousIntegration`, configured in `config/ci.rb`. Run `bin/ci` to execute the full pipeline locally:

1. **Setup** — `bin/setup --skip-server` (bundle, db:prepare)
2. **Style: Ruby** — `bin/rubocop` (Standard Ruby via `.rubocop.yml`)
3. **Security: Gem audit** — `bin/bundler-audit`
4. **Security: Importmap audit** — `bin/importmap audit`
5. **Security: Brakeman** — `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
6. **Tests: Rails** — `bin/rails test`
7. **Tests: Seeds** — `env RAILS_ENV=test bin/rails db:seed:replant`

**GitHub Actions** (`.github/workflows/ci.yml`):
1. **scan_ruby** — Brakeman security scan
2. **scan_js** — `importmap audit` for JS dependencies
3. **lint** — `bin/rubocop` with GitHub annotations
4. **test** — Full test suite + system tests with Chrome

## Testing

Minitest with fixtures. Test files in `test/models/` and `test/controllers/`. System tests use Capybara + Selenium with Chrome. Always run `bin/ci` for full validation (linting + security + tests + seeds).

Fixtures cover: users, sessions, workspaces (including archived/deleted variants), memories, contents.

## Project Conventions

- **Rich model methods** for multi-model transactions (e.g., `Memory.create_with_content`, `memory.update_with_content`)
- **Concerns** for shared model behaviors (soft delete, archive, pin, version)
- **Namespaced controllers** for workspace state-specific routes
- **Gem components** for all UI elements -- never hand-write HTML that replicates a gem component
- **Full I18n keys inside gem component blocks** — lazy `t(".key")` resolves to the gem partial's scope, not your app partial's scope. Always use `t("accounts.details.title")` instead of `t(".title")` when inside `do...end` blocks of gem-rendered partials. View locale keys go in `config/locales/views/en.yml`; partial key paths strip the underscore (e.g., `_details.html.erb` → `accounts.details.*`).
- **Data attributes** for component styling (`data-component`, `data-form-part`, `data-variant`, `data-size`)
- **Teardown pattern** for Stimulus controllers that manage state (implement `teardown()` method)
- **Custom form layouts** may omit `data-component="form"` with an explanatory comment; individual inputs still use their data-component attributes
- **Cookie-based UI state** for sidebar (signed cookie `recuerd0_sidebar_state`)
