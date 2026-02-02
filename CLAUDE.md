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
- **Component partials** in `app/views/components/` - shadcn/ui-inspired components (card, badge, alert, breadcrumb, dropdown_menu, sidebar)
- **Pagination** via Pagy gem
- UI state (sidebar open/closed, collapsible states) persisted in cookies

### Authentication

Uses Rails 8 built-in authentication generator with `Current.user` for accessing the logged-in user.
