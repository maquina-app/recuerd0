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
- `Workspaces::PinnedController` - pinned workspace listing
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

### Turbo / Hotwire Notes

- Layout uses `turbo_refresh_method_tag :morph` — Turbo caches page snapshots
- Dropdown menus and other stateful Stimulus-controlled elements should use `data-turbo-temporary` so Turbo strips them from cache snapshots, preventing stale DOM state on back navigation

### Authentication

Uses Rails 8 built-in authentication generator with `Current.user` for accessing the logged-in user.
