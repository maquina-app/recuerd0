# Tasks: Display Latest Version by Default

## Overview

- **Spec:** 2026-02-16-latest-version-default
- **Total Task Groups:** 4
- **Estimated Effort:** M (1 week)
- **Status:** In Progress

---

## Task Groups

### Model Layer

#### Task Group 1: Model Methods and Rename
**Dependencies:** None

- [ ] 1.0 Complete model changes
  - [ ] 1.1 Write focused tests for new version resolution methods
    - Test `current_version` returns self for root memory with no children
    - Test `current_version` returns highest-version child for root memory with children
    - Test `current_version` called on a child version delegates through root and returns the highest-version child
    - Test `current_version?` returns true for the latest child version
    - Test `current_version?` returns false for root memory when children exist
    - Test `current_version?` returns true for root memory with no children
    - Test `root_version?` returns true when `parent_memory_id` is nil
    - Test `root_version?` returns false for child versions
  - [ ] 1.2 Rename `latest_version?` to `root_version?` in Memory model
    - Rename method definition (line 63)
    - Update call in `all_versions` method (line 74)
  - [ ] 1.3 Update all `latest_version?` references across codebase
    - `app/models/concerns/searchable.rb:55`
    - `app/views/memories/edit.html.erb:17`
    - `app/views/memories/_version_timeline.html.erb:30`
    - `app/views/memories/versions/show.html.erb:70`
    - `app/views/memories/versions/show.html.erb:84`
  - [ ] 1.4 Grep codebase for any missed `latest_version?` references after rename
  - [ ] 1.5 Add `current_version` method to Memory model
    - Root with no children: return `self`
    - Root with children: return `child_versions.order(version: :desc).first`
    - Child version: return `root_memory.current_version`
  - [ ] 1.6 Add `current_version?` predicate to Memory model
    - Returns `self == root_memory.current_version`
  - [ ] 1.7 Ensure model tests pass
    - Run `test/models/memory_test.rb`

**Acceptance Criteria:**
- [ ] All memory model tests pass
- [ ] No references to `latest_version?` remain (except `latest_versions` scope)
- [ ] `current_version` correctly resolves from root, child, and no-children scenarios

---

### HTML Views Layer

#### Task Group 2: Workspace List and Memory Show
**Dependencies:** Task Group 1

- [ ] 2.0 Complete HTML view changes
  - [ ] 2.1 Write focused tests for version display behavior
    - Test workspace show displays latest version's title and body preview for versioned memories
    - Test workspace show displays root memory content when no child versions exist
    - Test memory show renders latest version content when navigating to root memory with versions
    - Test memory show renders specific version when navigating directly to a child version
    - Test version dropdown marks latest version as "(current)" regardless of viewed version
  - [ ] 2.2 Update `WorkspacesController#show` to resolve current versions
    - After loading root memories, map each to its `current_version` for display
    - Eager-load child version content to avoid N+1: include `child_versions: :content`
  - [ ] 2.3 Update `_memory.html.erb` partial for current version display
    - Display current version's `display_title`, `content&.body`, `tags`, `source`, `version_label`
    - Update "View Details" link to navigate to `workspace_memory_path(workspace, memory.current_version)`
    - Version badge shows current version label
  - [ ] 2.4 Update `MemoriesController#show` to resolve current version
    - When `@memory` is a root with child versions, replace `@memory` with `@memory.current_version`
    - Load `@all_versions` from the original memory (before resolution) for dropdown
  - [ ] 2.5 Update version dropdown in `memories/show.html.erb`
    - Change "(current)" label: use `version.current_version?` instead of `version == @memory`
    - Keep `selected` based on `version == @memory` (the version being viewed)
  - [ ] 2.6 Update version info card in `memories/show.html.erb`
    - "Current: vN" reflects displayed version
  - [ ] 2.7 Ensure HTML view tests pass
    - Run `test/controllers/memories_controller_test.rb`
    - Run `test/controllers/workspaces_controller_test.rb`

**Acceptance Criteria:**
- [ ] Workspace list shows latest version content for versioned memories
- [ ] Memory show defaults to latest version when navigating to root
- [ ] Version dropdown always labels newest version as "(current)"
- [ ] No N+1 queries in workspace memory list

---

### API Layer

#### Task Group 3: API Endpoints
**Dependencies:** Task Group 1

- [ ] 3.0 Complete API changes
  - [ ] 3.1 Write focused tests for API version resolution
    - Test `GET /workspaces/:id/memories.json` returns latest version data for versioned memories
    - Test `GET /workspaces/:id/memories/:id.json` returns latest version content when requesting root ID
    - Test `GET /workspaces/:id/memories/:id.json` returns specific version when requesting child version ID
    - Test API index URL field points to current version
  - [ ] 3.2 Update `MemoriesController#index` for JSON response
    - Resolve current versions for JSON rendering (same pattern as HTML)
    - Ensure eager-loading covers child version content
  - [ ] 3.3 Update `MemoriesController#show` JSON path
    - The in-place resolution from Task 2.4 applies to both HTML and JSON formats
    - Verify `_memory.json.jbuilder` cache key works with resolved version
  - [ ] 3.4 Verify `_memory.json.jbuilder` cache behavior
    - Cache key changes when rendering current_version instead of root — confirm this is correct (fresh data for each version)
    - URL field should point to the rendered version
  - [ ] 3.5 Ensure API tests pass
    - Run API-specific memory tests

**Acceptance Criteria:**
- [ ] API index returns latest version data per memory
- [ ] API show returns latest version content for root memory requests
- [ ] Explicit child version access returns that specific version
- [ ] JSON caching works correctly with resolved versions

---

### Testing & Verification

#### Task Group 4: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-3

- [ ] 4.0 Review and fill critical test gaps
  - [ ] 4.1 Review all tests from Groups 1-3
    - Model tests: 8 from 1.1
    - HTML tests: 5 from 2.1
    - API tests: 4 from 3.1
    - Total existing: 17 new/updated tests
  - [ ] 4.2 Identify critical gaps for this feature
    - Search results linking to versioned memories
    - Export job handling of versioned memories
    - Edit flow for versioned memories
    - Pin display on versioned memories
  - [ ] 4.3 Add up to 8 strategic tests
    - Test search results link to current version for versioned memories
    - Test workspace memory list with mix of versioned and non-versioned memories
    - Test current_version resolution when multiple child versions exist (returns highest, not most recent by date)
    - Test memory edit page for a root memory with versions (does it edit the right version?)
  - [ ] 4.4 Run feature-specific tests
    - Run `test/models/memory_test.rb`
    - Run `test/controllers/memories_controller_test.rb`
    - Run `test/controllers/workspaces_controller_test.rb`
    - Do NOT run entire test suite yet
  - [ ] 4.5 Run full CI
    - Run `bin/ci` to verify nothing is broken across the entire app

**Acceptance Criteria:**
- [ ] All feature-specific tests pass
- [ ] Full CI passes
- [ ] Latest version displayed correctly across all surfaces

---

## Execution Order

1. Model Layer (Task Group 1)
2. HTML Views Layer (Task Group 2) — can start immediately after Group 1
3. API Layer (Task Group 3) — can start immediately after Group 1, parallel with Group 2
4. Testing & Verification (Task Group 4)

---

## Progress Log

| Date | Task | Status | Notes |
|------|------|--------|-------|
