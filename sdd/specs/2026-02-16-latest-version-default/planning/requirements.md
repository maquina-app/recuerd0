# Spec Requirements: Display Latest Version by Default

## Initial Description

Versioned memories currently display the oldest version (root, v1) by default across all surfaces — workspace memory list, memory show page, and API responses. The latest version should always be treated as the source of truth and displayed by default everywhere.

## Requirements Discussion

### Questions & Answers

**Q1:** For the workspace memory list, should we show the root memory card but with the latest version's content (title, body, tags), or should the card link directly to the latest version?
**A:** Always point to the latest version — it is the source of truth. Previous versions or the original may be out of date.

**Q2:** For the memory show page, when navigating to a root memory that has versions, should it automatically redirect to the latest version or render the latest version in-place?
**A:** Render latest in-place. No redirect — load and display the latest version content without changing the URL.

**Q3:** For the version dropdown on the show page, should the latest version be marked as "(current)" instead of whichever version you're viewing?
**A:** Yes, the newest version is always labeled "(current)" in the dropdown, regardless of which version you're viewing.

### Existing Code to Reference

**Similar Features Identified:**
- **Versionable concern** — `app/models/concerns/versionable.rb` — defines `all_versions`, `latest_version?`, `root_memory`, `create_version!`
- **Memory model** — `app/models/memory.rb` — `latest_versions` scope (root memories only), `child_versions` association
- **Searchable concern** — Already indexes the newest version's content under the root memory's ID — good pattern to follow
- **MemoriesController** — `app/controllers/memories_controller.rb` — `show` loads `@memory` and `@all_versions`
- **WorkspacesController#show** — loads memories via `latest_versions` scope
- **API MemoriesController** — JSON endpoints return specific memory by ID
- **Versions controller** — `app/controllers/memories/versions_controller.rb` — timeline and version navigation
- **Memory partial** — `app/views/memories/_memory.html.erb` — card display in workspace list
- **Memory show view** — `app/views/memories/show.html.erb` — version dropdown, content display

## Visual Assets

No visual assets provided. Changes are to query logic and display behavior.

## Requirements Summary

### Functional Requirements

- Workspace memory list: show the latest version's title, body preview, tags, and timestamps for each root memory card; link "View Details" to the latest version
- Memory show page: when loading a root memory that has child versions, render the latest version's content in-place (no redirect, no URL change)
- Memory show page: version dropdown labels the newest version as "(current)" regardless of which version is being viewed
- API `GET /workspaces/:id/memories.json`: return latest version content for each memory in the list
- API `GET /workspaces/:id/memories/:id.json`: when the requested ID is a root memory with versions, return the latest version's content
- API versions endpoint behavior unchanged — explicitly requesting a version by ID still returns that specific version

### Non-Functional Requirements

- No new database tables or migrations
- Minimize N+1 queries — eager-load latest version content where possible
- Existing search behavior unchanged (already indexes newest version)

### Reusability Opportunities

- The `Searchable` concern already resolves to newest version content — similar pattern can be used in display logic
- `all_versions` method on Memory already orders by version number
- `child_versions` association can provide `.order(version: :desc).first` for latest

### Scope Boundaries

**In Scope:**
- Workspace show memory list display
- Memory show page default version rendering
- Version dropdown "(current)" label
- API index and show endpoints default version behavior
- Test updates for all affected surfaces

**Out of Scope:**
- Changing the versioning data model (parent_memory_id stays on root)
- Modifying version creation or consolidation logic
- Changing the versions timeline page behavior
- Search behavior changes (already correct)
- Changing how pins work with versions

### Technical Considerations

- The `latest_versions` scope currently means "root memories" — this naming may become confusing since "latest" will now mean "newest version"; consider whether to rename or add a new scope
- Root memories with no child versions should continue to work as-is (they are their own latest version)
- The `content` association belongs to each version individually — the latest version's content must be loaded, not the root's
- `memory.content.body` is used for truncated preview in the list — must point to latest version's content
- Version dropdown currently marks the viewed version as "(current)" — needs to always mark the highest version number instead
