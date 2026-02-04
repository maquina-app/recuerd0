# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Recuerd0 is a Rails 8 application for managing memories organized into workspaces. Built with Hotwire (Turbo + Stimulus), Tailwind CSS, and SQLite. Follows the One Person Framework philosophy: SQLite for all data needs (including cache, jobs, and WebSockets via Solid libraries), Kamal for deployment, importmaps instead of Node.js.

See `docs/technical-guide.md` for a comprehensive technical reference and `docs/ui-patterns.md` for the complete UI patterns catalog.

## Commands

```bash
# Development
bin/dev                          # Start server with Tailwind CSS watcher (foreman, port 3820)
bin/rails server                 # Rails server only

# Testing
bin/rails test                   # Run all tests
bin/rails test test/models/memory_test.rb           # Run single test file
bin/rails test test/models/memory_test.rb:42        # Run single test at line

# Linting
bundle exec standardrb           # Check Ruby style
bundle exec standardrb --fix     # Auto-fix Ruby style issues

# Database
bin/rails db:migrate             # Run migrations
bin/rails db:rollback            # Rollback last migration

# Deployment
bin/kamal deploy                 # Deploy via Kamal
bin/kamal console                # Remote Rails console
```

## Architecture

### Domain Model

- **User** → has many Workspaces, Sessions, Pins (max 10 pins, enforced in controller)
- **Workspace** → has many Memories (counter cached); supports soft delete (30-day retention), archiving, and pinning
- **Memory** → belongs to Workspace (touch: true); has one Content; supports versioning (flat branching from any version) and pinning
- **Content** → stores the body text of a Memory (Markdown via Commonmarker); touches parent Memory
- **Pin** → polymorphic; allows users to pin Workspaces or Memories with position ordering
- **Session** → belongs to User; stores ip_address and user_agent

### Use Cases Pattern

Business logic for complex operations is extracted into `app/use_cases/`. Each class exposes `.call` and wraps work in a transaction.

```ruby
# Creating a memory with content
CreateMemory.call(workspace, title: "...", content: "...", tags: [...])

# Updating memory and content in transaction
UpdateMemory.call(memory, title: "...", content: "...")

# Creating a new version (branches from any version, resolves root parent)
CreateMemoryVersion.call(original_memory, content: "...")
```

### Model Concerns

Located in `app/models/concerns/`:

- **SoftDeletable** - `deleted_at` timestamp, 30-day retention, default scope excludes deleted. `soft_delete`/`restore`/`destroy!` (permanent). Overrides `destroy` to soft delete.
- **Archivable** - `archived_at` timestamp, `archive`/`unarchive`/`toggle_archive` methods
- **Pinnable** - polymorphic pinning with position ordering, `pin!`/`unpin!`/`toggle_pin_for!` methods. Validates `active?` before pinning.
- **Versionable** - memory versioning with parent/child relationships. All versions share a root parent (flat tree). `consolidate_versions!` to collapse history.

Workspace state hierarchy: active (default) → archived → deleted. State changes auto-unpin.

### Namespaced Controllers

Controllers under `workspaces/` handle specific workspace states:
- `Workspaces::ArchivesController` - archived workspace operations (uses `WorkspaceScoped` concern)
- `Workspaces::DeletedController` - deleted workspace operations (restore, permanent delete)
- `Memories::VersionsController` - memory version operations (`destroy` consolidates, doesn't delete)

### Controller Concerns

- **Authentication** (`app/controllers/concerns/authentication.rb`) - `before_action :require_authentication` by default. Opt-out with `allow_unauthenticated_access`. Uses `Current.user` / `Current.session`.
- **WorkspaceScoped** (`app/controllers/concerns/workspace_scoped.rb`) - Loads workspace with `with_deleted` scope for namespaced controllers.

### Frontend

- **Stimulus controllers** in `app/javascript/controllers/`:
  - `markdown-editor` - Write/Preview tabs, submits preview form to Turbo Frame, teardown resets to Write
  - `tag-input` - Add/remove tags with Enter/comma/Backspace, renders badge chips, hidden inputs for form submission
  - `details` - Closes `<details>` on outside click (100ms delay prevents immediate close)
  - `scroll-to-top` - FAB appears at 300px scroll, smooth scroll, teardown hides button
  - `navigate` - Navigates on `<select>` change via Turbo.visit
  - Toast/toaster/sidebar/dropdown controllers are provided by the gem.
- **Component partials** in `app/views/components/` — provided by the `maquina-components` gem (not local files). Components include: card, badge, alert, breadcrumb, dropdown_menu, sidebar, pagination, empty, separator, toaster, toast
- **App-specific components** in `app/views/application/components/` — `tag_input`, pin buttons
- **Pagination** via Pagy gem, rendered with `pagination_nav(pagy, :route_helper)` from the gem's `PaginationHelper`
- **Breadcrumbs** via `breadcrumbs({ "Label" => path }, "Current Page")` from the gem's `BreadcrumbsHelper`
- **Custom confirm dialog** — overrides `Turbo.config.forms.confirm` with a styled `<dialog>` returning a Promise
- UI state (sidebar open/closed) persisted in cookies (`recuerd0_sidebar_state`)

### maquina-components Gem

Component partials live in the gem, not in the app. The app's `MaquinaComponentsHelper` (`app/helpers/maquina_components_helper.rb`) includes:
- `MaquinaComponents::IconsHelper` — `icon_for(:name)` helper with app-level SVG fallbacks via `main_icon_svg_for`
- `MaquinaComponents::PaginationHelper` — `pagination_nav(pagy, :route_helper, params: {})` and `pagination_simple`
- `MaquinaComponents::BreadcrumbsHelper` — `breadcrumbs(links_hash, current_page)` and `responsive_breadcrumbs`
- `MaquinaComponents::ToastHelper` — `toast_flash_messages`, `toast(variant, title, description:)`, `toast_success`, `toast_error`, `toast_warning`, `toast_info`

Component partials accept `css_classes:` for styling and `**html_options` (including `data:`) for extra attributes. Data attributes are merged with the component's own data attributes (e.g., `data-component`, `data-controller`).

#### Component variant reference

- **alert** — `:default`, `:destructive`, `:success`, `:warning` (no `:info` variant)
- **empty** — `:default`, `:outline` (`:outline` renders a dashed border; there is no `:dashed` variant)
- **badge** — `:default`, `:secondary`, `:destructive`, `:warning`, `:outline`
- **toast** — `:default`, `:success`, `:info`, `:warning`, `:error`

#### Form data attributes

The gem styles form elements via `[data-component]` and `[data-form-part]` attribute selectors:

- `data-component="form"` → `grid gap-6` (omit for custom layouts, document with a comment)
- `data-form-part="group"` → `grid gap-2` (8px between label, input, and error)
- `data-form-part="error"` → `text-sm font-medium` + destructive color
- `data-component="label"` → `text-sm font-medium leading-none select-none`
- `data-component="input"` → `h-9 rounded-md border shadow-xs` + focus ring (3px translucent ring via color-mix)
- `data-component="textarea"` → similar to input, flexible height
- `data-component="button"` → styled button with `data-variant` and `data-size` support

When building custom form layouts that omit `data-component="form"`, still use `data-form-part="group"` wrappers and individual `data-component` attributes on inputs for consistent styling.

Note: `data-form-part="error"` uses `--destructive-foreground` (near-white, designed for text ON destructive backgrounds). For inline error text on standard backgrounds, add `class="text-destructive"` to override with the visible red color.

#### Alert `icon:` parameter

Use the built-in `icon:` local instead of manually placing icons inside the block. The component sets `data-has-icon` and uses a CSS grid layout automatically:

```erb
<%= render "components/alert", variant: :warning, icon: :trash_2, css_classes: "mb-6" do %>
  <strong>Title</strong>
  <p class="mt-1">Description text.</p>
<% end %>
```

#### Sidebar `active:` parameter

The `sidebar/menu_button` partial accepts `active:` (default `false`) to highlight the current section:

```erb
<%= render "components/sidebar/menu_button",
    title: "Workspaces",
    url: workspaces_path,
    icon_name: :folders,
    active: current_page?(workspaces_path) %>
```

#### Theme color variables

The app's CSS theme is defined in `app/assets/tailwind/application.css` using oklch colors with **hue 150 (green)** as the primary. The gem's component CSS references raw CSS variables (e.g., `var(--success)`, `var(--warning-foreground)`) — these must be defined in `:root` and `.dark` blocks. The `@theme` block maps them to Tailwind utilities with `--color-` prefix.

Required semantic color variables (beyond the standard set):
- `--destructive-foreground` — text on destructive backgrounds
- `--success` / `--success-foreground` — used by alert and toast components
- `--warning` / `--warning-foreground` — used by alert and toast components
- `--info` / `--info-foreground` — used by toast info variant

Alert variants use subtle light-tinted backgrounds with dark text (not bold colored banners). The warning hue (85) is a warm yellow-green that complements the green theme without clashing.

#### Custom CSS overrides (`app/assets/tailwind/application.css`)

- `.tag-input-container` — mirrors gem's `[data-component="input"]` shadow and focus ring for the tag input component. Includes dark mode variant.
- `.editor-textarea[data-component="textarea"]` — removes border, shadow, radius, and resize for flush rendering inside the editor container.

When creating compound input components (like tag input), match the gem's focus ring pattern:
```css
/* Base: */ box-shadow: var(--shadow-xs, 0 1px 2px 0 rgb(0 0 0 / 0.05));
/* Focus: */ border-color: var(--ring);
             box-shadow: var(--shadow-xs), 0 0 0 3px color-mix(in oklch, var(--ring) 50%, transparent);
```

#### Toast / Toaster usage

The layout uses the gem's toaster container with `toast_flash_messages` to render flash-based toasts:

```erb
<%= render "components/toaster", position: :bottom_right do %>
  <%= toast_flash_messages %>
<% end %>
```

Individual toasts are rendered with `render "components/toast"`:

```erb
<%= render "components/toast", variant: :success, title: "Saved!", description: "Your changes were saved." %>
```

Always use the gem's `render "components/..."` partials — never hand-write inline HTML to replicate a gem component's output. The gem manages data attributes, Stimulus controllers, and CSS selectors internally.

### Turbo / Hotwire Notes

- Layout uses `turbo_refresh_method_tag :morph` — Turbo caches page snapshots
- `data-turbo-temporary` does **not** work with morph mode for cleaning up stateful elements
- Stateful Stimulus components (dropdowns, modals) need cleanup via Turbo cache events:
  - `turbo:before-cache` — clean the live DOM before Turbo snapshots it
  - `turbo:before-render` — clean `event.detail.newBody` before Turbo paints it on Back/Forward (prevents flash of stale state)
- `app/javascript/controllers/application.js` implements the [Better Stimulus global teardown pattern](https://www.betterstimulus.com/turbo/teardown.html): any Stimulus controller with a `teardown()` method gets called on `turbo:before-cache`
- `app/javascript/application.js` has manual DOM cleanup for gem-provided dropdown menus (until the gem adds its own `teardown()`)
- Forms using `local: true` bypass Turbo Drive — used when Stimulus controllers need standard page navigation lifecycle (e.g., markdown editor)

### Authentication

Uses Rails 8 built-in authentication generator with `Current.user` for accessing the logged-in user. Sessions stored in database with signed permanent cookies (httponly, same_site: lax). Login rate-limited to 10 attempts per 3 minutes. Password reset via encrypted token in email.

### Database

SQLite for everything. Production uses 4 separate SQLite files (primary, cache, queue, cable) in a persistent Docker volume. Counter cache on `workspaces.memories_count`. Key composite indexes: `memories(parent_memory_id, version)` and `pins(user_id, pinnable_type, pinnable_id)` (unique).

### Deployment

Docker multi-stage build with jemalloc. Kamal deploys to single server with Let's Encrypt SSL. Thruster provides HTTP caching/compression. Solid Queue runs in-process via `SOLID_QUEUE_IN_PUMA=true`. Entrypoint auto-runs `db:prepare`.

## Rails MCP Server

A Rails MCP server is available for introspecting the application and loading documentation guides. Use `mcp__rails__execute_tool` to call tools and `mcp__rails__search_tools` to discover them.

### Available guides

Load guides with `execute_tool("load_guide", { library: "<library>", guide: "<guide_name>" })`. Omit `guide` to list all available guides for a library.

- **Rails** (54 guides) — `routing`, `active_record_querying`, `testing`, `caching_with_rails`, `security`, `configuring`, etc.
- **Turbo** (13 guides) — `handbook/02_drive`, `handbook/03_page_refreshes`, `handbook/04_frames`, `handbook/05_streams`, `reference/events`, `reference/attributes`, etc.
- **Stimulus** (16 guides) — `reference/actions`, `reference/controllers`, `reference/values`, `reference/targets`, `reference/lifecycle_callbacks`, `reference/outlets`, etc.
- **Kamal** (58 guides) — `configuration/overview`, `configuration/proxy`, `commands/deploy`, `commands/rollback`, `upgrading/overview`, `hooks/overview`, etc.

### Other useful tools

- `analyze_models` — introspect ActiveRecord models (associations, validations, scopes)
- `analyze_controller_views` — inspect controllers (callbacks, strong params, renders)
- `get_routes` — list HTTP routes with filtering
- `get_schema` — database schema for all or specific tables
- `project_info` — Rails version, directory structure, project overview
