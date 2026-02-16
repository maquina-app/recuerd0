# Specification: Display Latest Version by Default

## Goal

Make all surfaces display the latest (highest version number) version of a memory by default. The latest version is the source of truth — previous versions may be outdated and should only appear when explicitly navigated to via the version dropdown or timeline.

## User Stories

- As a user browsing my workspace, I want to see the latest version's title and content preview for each memory so that the list reflects current knowledge.
- As a user viewing a memory, I want the latest version loaded by default so that I don't have to manually switch from the outdated root version.
- As an API consumer, I want memory endpoints to return the latest version's content by default so that integrations always get the current data.

## Specific Requirements

**Memory Model — `current_version` method**
- Add `current_version` instance method that returns the latest version (highest version number) for a root memory, or delegates to root and resolves from there for child versions
- For a root memory with no child versions, `current_version` returns `self`
- For a root memory with child versions, `current_version` returns `child_versions.order(version: :desc).first`
- For a child version, `current_version` returns `root_memory.current_version`
- Add `current_version?` predicate that returns `true` if `self == root_memory.current_version`
- Rename existing `latest_version?` to `root_version?` to avoid confusion (it checks `parent_memory_id.nil?`, which means "root", not "latest")
- Update all references to `latest_version?` across the codebase to use `root_version?`
- The `latest_versions` scope (root memories only) keeps its name — it is a query scope for listing, not a version predicate

**Workspace Memory List — Card Display**
- In `WorkspacesController#show`, after loading root memories via `latest_versions` scope, resolve each memory's current version for display
- The `_memory.html.erb` partial should display the current version's title, body preview, tags, source, and timestamps
- The version badge should show the current version's label (e.g., "v3") not "v1"
- The "View Details" link should navigate to the current version: `workspace_memory_path(workspace, memory.current_version)`
- Eager-load current version content to avoid N+1 queries

**Memory Show Page — Default Rendering**
- In `MemoriesController#show`, when `@memory` is a root memory with child versions, replace `@memory` with its `current_version` in-place (no redirect, no URL change)
- All display elements (title, content, tags, metadata, version badge) render from the resolved current version
- `@all_versions` continues to load all versions for the dropdown

**Memory Show Page — Version Dropdown**
- The "(current)" label in the version dropdown should always appear on the latest version (highest version number), not on whichever version is being viewed
- When viewing an older version, it shows as selected but without "(current)"
- When viewing the latest version, it shows as both selected and "(current)"

**Memory Show Page — Version Info Card**
- The "Current: vN" text in the version info card should reflect the actual version being displayed
- The child versions count should reflect the displayed version's children

**API — Memory Index (`GET /workspaces/:id/memories.json`)**
- Return the current version's data (title, tags, version, version_label, timestamps, URL) for each root memory
- The URL field should point to the current version
- Content body in `_memory_with_content.json.jbuilder` should come from the current version

**API — Memory Show (`GET /workspaces/:id/memories/:id.json`)**
- When the requested ID is a root memory with child versions, return the current version's content
- When the requested ID is a specific child version, return that version as-is (explicit version access)

**`latest_version?` → `root_version?` Rename**
- Rename the method in the Memory model
- Update all view references: `memories/show.html.erb`, `memories/versions/` views
- Update all test references
- Grep the codebase after renaming to catch any missed references

## Existing Code to Leverage

**Memory model** (`app/models/memory.rb`)
- `latest_version?` (line 63) — rename to `root_version?`, same logic (`parent_memory_id.nil?`)
- `root_memory` (line 68) — used to resolve from any version to root
- `all_versions` (line 73) — ordered by `:version`, useful for finding max
- `child_versions` association (line 8) — `order(version: :desc).first` gives latest
- `latest_versions` scope (line 17) — keeps its name, used for listing root memories

**WorkspacesController#show** (`app/controllers/workspaces_controller.rb:35-40`)
- Loads root memories with `.latest_versions.includes(:content, :child_versions, :pins)`
- Already eager-loads `child_versions` — can resolve current version from loaded data

**MemoriesController#show** (`app/controllers/memories_controller.rb:23-31`)
- Loads `@memory` via `set_memory` (finds by ID in workspace)
- Loads `@all_versions` — can resolve current version before rendering

**Memory card partial** (`app/views/memories/_memory.html.erb`)
- Displays `memory.display_title`, `memory.content&.body`, `memory.version_label`, `memory.tags`
- "View Details" link at line 81: `workspace_memory_path(workspace, memory)`

**Memory show view** (`app/views/memories/show.html.erb`)
- Version dropdown at lines 50-57: marks `version == @memory` as "(current)"
- Version info card at lines 166-190: shows `@memory.version_label` and child count

**JSON views** (`app/views/memories/`)
- `_memory.json.jbuilder` — renders memory attributes, cached by memory
- `_memory_with_content.json.jbuilder` — includes content body
- `index.json.jbuilder` — renders array of `_memory` partials
- `show.json.jbuilder` — renders `_memory_with_content`

**Searchable concern**
- Already indexes newest version's content under root memory's ID — same pattern we're applying to display

## Out of Scope

- Changing the versioning data model (parent_memory_id, flat tree structure)
- Modifying version creation or consolidation logic
- Changing the versions timeline page default behavior (it already shows newest first)
- Search behavior changes (already indexes newest version)
- Pin behavior with versions
- Changing how `create_version!` or `update_with_content` work
