# Tasks: REST API Search Endpoint

## Task 1: Add `api_search` scope to Searchable concern

**File:** `app/models/concerns/searchable.rb`

Add a new scope `api_search` that passes queries to FTS5 MATCH without quoting, enabling full operator support (AND, OR, NOT, phrase quotes, column filters, grouping). The existing `full_search` scope remains unchanged for HTML use.

**Acceptance:**
- `api_search` scope passes raw queries to FTS5 MATCH
- Supports AND, OR, NOT, `"phrase"`, `title:term`, `body:term`, `(grouping)`
- Returns `none` for blank or too-short queries
- Existing `full_search` behavior unchanged
- Existing tests pass

---

## Task 2: Update ApiHelpers pagination to preserve query params

**File:** `app/controllers/concerns/api_helpers.rb`

Update `pagination_link_header` to preserve query parameters (like `q`, `workspace_id`) in pagination Link header URLs. Currently only uses `request.path`.

**Acceptance:**
- Pagination links include `q` and other query params when present
- Existing pagination behavior unchanged for endpoints without extra params
- All existing API tests continue to pass

---

## Task 3: Add SearchHelper with memory_snippet

**File:** `app/helpers/search_helper.rb`

Create helper module with `memory_snippet(memory, length: 200)` method that:
- Extracts plain text from memory content body
- Strips markdown formatting characters (#, *, _, `, ~, [], (), >, |, -)
- Collapses whitespace and newlines
- Truncates to specified length with "..." omission
- Returns empty string for nil content

**Acceptance:**
- Returns clean text snippet from memory content
- Handles nil content gracefully
- Strips markdown formatting

---

## Task 4: Update SearchController for JSON API

**File:** `app/controllers/search_controller.rb`

Extend `index` action with `respond_to` for HTML/JSON:
- JSON: validate query presence (422 if blank), validate minimum length (422 if < 3 chars)
- JSON: use `api_search` scope (raw FTS5 operators) instead of `full_search`
- JSON: rescue FTS5 syntax errors → 422 with "Invalid search query syntax"
- JSON: allow query up to 100 chars (HTML stays at 30)
- JSON: optional `workspace_id` filter parameter (scoped to Current.account)
- JSON: set pagination headers
- HTML: behavior unchanged

**Acceptance:**
- `GET /search.json?q=architecture AND design` returns matching results
- `GET /search.json?q=title:API` searches title column only
- `GET /search.json` without `q` returns 422
- `GET /search.json?q=ab` returns 422
- `GET /search.json?q=AND OR` (invalid syntax) returns 422
- `GET /search.json?q=query&workspace_id=1` filters to workspace
- HTML search unchanged

---

## Task 5: Create Jbuilder template for search results

**File:** `app/views/search/index.json.jbuilder`

Render JSON response with:
- `query` — the submitted search query
- `total_results` — total count from pagy
- `results` — array of memories using existing `_memory` partial plus `snippet` field

**Acceptance:**
- Response matches documented JSON structure
- Each result includes workspace context, snippet, and all memory fields
- Reuses existing `_memory.json.jbuilder` partial

---

## Task 6: Write API search tests

**File:** `test/controllers/api/search_test.rb`

Test cases:
- Returns results for matching query (200 with results array)
- Returns empty results for no matches (200 with empty array)
- Returns 422 for missing `q` parameter
- Returns 422 for query shorter than 3 characters
- Returns 422 for invalid FTS5 syntax
- Includes pagination headers (X-Page, X-Total, etc.)
- Respects account isolation (cannot see other accounts' memories)
- Filters by `workspace_id` when provided
- Returns 404 for invalid `workspace_id`
- Requires authentication (401 without token)
- Works with `read_only` token
- Response includes `snippet`, `query`, and `total_results` fields
- Supports AND/OR/NOT operators
- Supports column filters (title:, body:)
- Existing HTML search tests still pass

**Acceptance:**
- All new tests pass
- All existing tests pass (`bin/rails test`)

---

## Task 7: Update API documentation

**Files:** `docs/API.md`, `CLAUDE.md`

Add Search section to API docs:
- Endpoint description, parameters, response format
- FTS5 query operators table with examples
- Error cases
- Update CLAUDE.md API endpoints list

**Acceptance:**
- Documentation complete and accurate
- Includes operator reference
- Consistent with existing doc style
