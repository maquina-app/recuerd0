# Recuerd0 Technical Guide

## Overview

Recuerd0 is a personal knowledge management application built with Rails 8, Hotwire, and SQLite. Users organize markdown-formatted memories into workspaces, with support for versioning, pinning, archiving, and soft deletion. The application follows the One Person Framework philosophy: SQLite for all data storage, Solid libraries instead of Redis, Kamal for deployment, and zero JavaScript build tooling.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Framework | Rails 8.0.2 |
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
| Linting | Standard Ruby (RuboCop wrapper) |
| Testing | Minitest + Capybara + Selenium |

## Domain Model

```
User
 ├── has_many :sessions        (auth sessions)
 ├── has_many :workspaces      (owned workspaces)
 ├── has_many :pins            (polymorphic bookmarks)
 ├── has_many :pinned_workspaces  (through pins, active only)
 └── has_many :pinned_memories    (through pins)

Workspace
 ├── belongs_to :user
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

- `full_search(query)` scope — joins on `memories_search.memory_id`, returns root memories ordered by FTS rank. Returns `none` for queries shorter than 3 characters.
- `rebuild_search_index` — public method to manually reindex a memory.
- `update_search_index` (private, `after_save_commit`) — resolves the root memory, finds the newest version (highest `version` among children, or root itself), and indexes that version's title and body under the root's ID. This ensures `full_search` returns root memories compatible with the `latest_versions` scope.
- `delete_search_index` (private, `after_destroy_commit`) — deletes the FTS entry by root ID.
- Content changes trigger reindexing via `Content#reindex_memory` (`after_save_commit`).
- Bulk reindex: `bin/rails search:reindex`

## Rich Model Methods

Multi-model operations (Memory + Content) are handled by model methods on `Memory`, each wrapped in a transaction:

| Method | Purpose |
|--------|---------|
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
| `HomeController` | Public landing page. |
| `SessionsController` | Login/logout. Rate-limited to 10 attempts per 3 minutes. |
| `PasswordsController` | Token-based password reset via email. Anti-enumeration (always shows success). |

### Namespaced Controllers

| Controller | Purpose |
|-----------|---------|
| `Workspaces::ArchivesController` | List/show archived workspaces, archive/unarchive actions. |
| `Workspaces::DeletedController` | List/show deleted workspaces, restore/permanent-delete actions. |
| `Memories::VersionsController` | List/show/create versions. `destroy` consolidates (keeps one, removes others). |

### Controller Concerns

- **Authentication** (`app/controllers/concerns/authentication.rb`) - `before_action :require_authentication` by default. Opt-out with `allow_unauthenticated_access`. Session stored in signed permanent cookie (httponly, same_site: lax).
- **WorkspaceScoped** (`app/controllers/concerns/workspace_scoped.rb`) - Loads workspace with `with_deleted` scope for namespaced controllers.

## Routing Structure

```
Root:       GET /                                → home#index (public)
Auth:       resource  :session                   → sessions (login/logout)
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

Pins:       POST/DELETE pins/:pinnable_type/:pinnable_id → pins (polymorphic)

Health:     GET /up → rails/health#show
```

## Authentication

Rails 8 built-in authentication with `has_secure_password` (bcrypt).

- **Session model**: stores user_id, ip_address, user_agent in database
- **Current context**: `Current.session` / `Current.user` via `ActiveSupport::CurrentAttributes`
- **Cookie**: signed, permanent, httponly, same_site: lax (key: `:session_id`)
- **Password reset**: encrypted token via Rails message verifier, delivered by `PasswordsMailer`
- **Rate limiting**: 10 login attempts per 3 minutes

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

### Turbo / Hotwire Patterns

- **Morph mode**: `turbo_refresh_method_tag :morph` enables page morphing with cached snapshots
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

Custom overrides:
- `.tag-input-container` - Mirrors gem's input focus ring for the tag input component
- `.editor-textarea` - Removes border/shadow/radius for flush textarea inside editor container

## Database

### Schema

SQLite with 6 tables: `users`, `sessions`, `workspaces`, `memories`, `contents`, `pins`. Plus one FTS5 virtual table: `memories_search` (trigram tokenizer, columns: `title`, `body`, `memory_id UNINDEXED`).

**Notable indexes**:
- `users.email_address` (unique)
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

## Deployment

### Docker

Multi-stage Dockerfile: Ruby 3.4.2-slim base, jemalloc for memory optimization, Thruster for HTTP acceleration. Runs as non-root `rails` user (UID 1000). Entrypoint auto-runs `db:prepare` on server start.

### Kamal

Configured in `config/deploy.yml`. Single-server deployment with:
- Let's Encrypt SSL via Kamal proxy
- Persistent volume at `/rails/storage` for SQLite databases
- `SOLID_QUEUE_IN_PUMA=true` runs jobs in-process (no separate worker)
- Secrets: `RAILS_MASTER_KEY` from `config/master.key`, registry password from environment

### CI/CD

GitHub Actions (`.github/workflows/ci.yml`):
1. **scan_ruby** - Brakeman security scan
2. **scan_js** - `importmap audit` for JS dependencies
3. **lint** - Standard Ruby (RuboCop) with GitHub annotations
4. **test** - Full test suite + system tests with Chrome

## Testing

Minitest with fixtures. Test files in `test/models/` and `test/controllers/`. System tests use Capybara + Selenium with Chrome.

Fixtures cover: users, sessions, workspaces (including archived/deleted variants), memories, contents.

## Project Conventions

- **Rich model methods** for multi-model transactions (e.g., `Memory.create_with_content`, `memory.update_with_content`)
- **Concerns** for shared model behaviors (soft delete, archive, pin, version)
- **Namespaced controllers** for workspace state-specific routes
- **Gem components** for all UI elements -- never hand-write HTML that replicates a gem component
- **Data attributes** for component styling (`data-component`, `data-form-part`, `data-variant`, `data-size`)
- **Teardown pattern** for Stimulus controllers that manage state (implement `teardown()` method)
- **Custom form layouts** may omit `data-component="form"` with an explanatory comment; individual inputs still use their data-component attributes
- **Cookie-based UI state** for sidebar (signed cookie `recuerd0_sidebar_state`)
