# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Recuerd0 is a Rails 8 application for managing memories organized into workspaces. Built with Hotwire (Turbo + Stimulus), Tailwind CSS, and SQLite.

## Commands

```bash
# Development
bin/dev                          # Start server with Tailwind CSS watcher (foreman)
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
```

## Architecture

### Domain Model

- **User** → has many Workspaces, Sessions, Pins
- **Workspace** → has many Memories; supports soft delete, archiving, and pinning
- **Memory** → belongs to Workspace; has one Content; supports versioning and pinning
- **Content** → stores the actual body text of a Memory (Markdown)
- **Pin** → polymorphic; allows users to pin Workspaces or Memories

### Use Cases Pattern

Business logic for complex operations is extracted into `app/use_cases/`:

```ruby
# Creating a memory with content
CreateMemory.call(workspace, title: "...", content: "...", tags: [...])

# Updating memory and content in transaction
UpdateMemory.call(memory, title: "...", content: "...")

# Creating a new version (branches from any version)
CreateMemoryVersion.call(original_memory, content: "...")
```

### Model Concerns

Located in `app/models/concerns/`:

- **SoftDeletable** - `deleted_at` timestamp, 30-day retention, `soft_delete`/`restore`/`destroy!` methods
- **Archivable** - `archived_at` timestamp, `archive`/`unarchive` methods
- **Pinnable** - polymorphic pinning with position ordering, `pin!`/`unpin!`/`toggle_pin_for!` methods
- **Versionable** - memory versioning with parent/child relationships

Workspace state hierarchy: active (default) → archived → deleted

### Namespaced Controllers

Controllers under `workspaces/` handle specific workspace states:
- `Workspaces::ArchivesController` - archived workspace operations
- `Workspaces::DeletedController` - deleted workspace operations (restore, permanent delete)
- `Memories::VersionsController` - memory version operations

### Frontend

- **Stimulus controllers** in `app/javascript/controllers/` - sidebar, collapsible, dropdown, sonner (toasts), tag input
- **Component partials** in `app/views/components/` — provided by the `maquina-components` gem (not local files). Components include: card, badge, alert, breadcrumb, dropdown_menu, sidebar, pagination, empty, separator
- **Pagination** via Pagy gem, rendered with `pagination_nav(pagy, :route_helper)` from the gem's `PaginationHelper`
- **Breadcrumbs** via `breadcrumbs({ "Label" => path }, "Current Page")` from the gem's `BreadcrumbsHelper`
- UI state (sidebar open/closed, collapsible states) persisted in cookies

### maquina-components Gem

Component partials live in the gem, not in the app. The app's `MaquinaComponentsHelper` (`app/helpers/maquina_components_helper.rb`) includes:
- `MaquinaComponents::IconsHelper` — `icon_for(:name)` helper with app-level SVG fallbacks via `main_icon_svg_for`
- `MaquinaComponents::PaginationHelper` — `pagination_nav(pagy, :route_helper, params: {})` and `pagination_simple`
- `MaquinaComponents::BreadcrumbsHelper` — `breadcrumbs(links_hash, current_page)` and `responsive_breadcrumbs`

Component partials accept `css_classes:` for styling and `**html_options` (including `data:`) for extra attributes. Data attributes are merged with the component's own data attributes (e.g., `data-component`, `data-controller`).

#### Component variant reference

- **alert** — `:default`, `:destructive`, `:success`, `:warning` (no `:info` variant)
- **empty** — `:default`, `:outline` (`:outline` renders a dashed border; there is no `:dashed` variant)
- **badge** — `:default`, `:secondary`, `:destructive`, `:warning`, `:outline`

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

Alert variants use subtle light-tinted backgrounds with dark text (not bold colored banners). The warning hue (85) is a warm yellow-green that complements the green theme without clashing.

### Turbo / Hotwire Notes

- Layout uses `turbo_refresh_method_tag :morph` — Turbo caches page snapshots
- `data-turbo-temporary` does **not** work with morph mode for cleaning up stateful elements
- Stateful Stimulus components (dropdowns, modals) need cleanup via Turbo cache events:
  - `turbo:before-cache` — clean the live DOM before Turbo snapshots it
  - `turbo:before-render` — clean `event.detail.newBody` before Turbo paints it on Back/Forward (prevents flash of stale state)
- `app/javascript/controllers/application.js` implements the [Better Stimulus global teardown pattern](https://www.betterstimulus.com/turbo/teardown.html): any Stimulus controller with a `teardown()` method gets called on `turbo:before-cache`
- `app/javascript/application.js` has manual DOM cleanup for gem-provided dropdown menus (until the gem adds its own `teardown()`)

### Authentication

Uses Rails 8 built-in authentication generator with `Current.user` for accessing the logged-in user.

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
