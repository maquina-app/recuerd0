# REST API: Search Endpoint

## Overview

Add a search endpoint to the REST API that allows programmatic full-text search across memories in all active workspaces within the authenticated account. The endpoint leverages the existing FTS5 search infrastructure with full query operator support, and follows established API patterns for authentication, pagination, and error handling.

## Motivation

AI agents and CLI tools need to search through memories the same way they search through markdown files on a filesystem — by sending a query and getting back ranked results with content snippets and workspace context. The existing HTML search controller only serves browser clients and wraps all queries as quoted phrases (neutralizing operators). A JSON API endpoint enables programmatic access with full FTS5 operator support for powerful search capabilities.

## FTS5 Query Operators

The search endpoint exposes the full FTS5 trigram tokenizer query syntax. The API passes queries directly to FTS5 MATCH (with safety sanitization), unlike the HTML search which wraps queries in quotes as a phrase.

### Supported operators

| Operator | Example | Description |
|----------|---------|-------------|
| Simple term | `architecture` | Matches documents containing the substring |
| AND | `architecture AND design` | Both terms must appear |
| OR | `meeting OR standup` | Either term can appear |
| NOT | `design NOT draft` | First term must appear, second must not |
| Phrase | `"project timeline"` | Exact phrase match |
| Column filter | `title:architecture` | Search only in title field |
| Column filter | `body:implementation` | Search only in body field |
| Grouping | `(meeting OR standup) AND notes` | Parentheses for precedence |
| Prefix | `arch*` | Prefix matching (note: trigram tokenizer requires at least 3 chars) |

### Examples for agent tools

```
# Find memories about architecture decisions
GET /search.json?q=architecture AND decision

# Find memories with "API" in title
GET /search.json?q=title:API

# Find memories about deployment but not Docker
GET /search.json?q=deployment NOT docker

# Exact phrase search
GET /search.json?q="project timeline"

# Combined operators
GET /search.json?q=(meeting OR standup) AND notes

# Scope to a specific workspace
GET /search.json?q=design&workspace_id=1
```

## Endpoint

```
GET /search.json?q=<query>
```

### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| q | string | Yes | FTS5 search query (3-100 characters). Supports AND, OR, NOT, phrase quotes, column filters (title:/body:), and grouping. |
| page | integer | No | Page number (default: 1) |
| workspace_id | integer | No | Optional filter to limit search to a specific workspace |

### Authentication

- Bearer token required (`Authorization: Bearer <token>`)
- `read_only` permission is sufficient (this is a GET endpoint)
- Session cookie authentication also supported (for browser-based JSON requests)

### Success Response `200 OK`

```json
{
  "query": "architecture AND design",
  "total_results": 3,
  "results": [
    {
      "id": 1,
      "title": "Design Doc",
      "version": 1,
      "version_label": "v1",
      "has_versions": false,
      "tags": ["design"],
      "source": "manual",
      "snippet": "Initial architecture overview. The system uses a layered design...",
      "created_at": "2026-01-20T09:00:00Z",
      "updated_at": "2026-02-03T16:45:00Z",
      "url": "https://recuerd0.com/workspaces/1/memories/1",
      "workspace": {
        "id": 1,
        "name": "Project Notes",
        "url": "https://recuerd0.com/workspaces/1"
      }
    }
  ]
}
```

**Response fields:**

| Field | Description |
|-------|-------------|
| query | The search query as submitted |
| total_results | Total number of matching memories across all pages |
| results | Array of matching memories, ordered by FTS5 relevance rank then by `updated_at DESC` |
| snippet | A plain-text excerpt from the memory content body (up to 200 characters, markdown stripped) |

### Pagination Headers

Standard pagination headers as used by other list endpoints:

| Header | Description |
|--------|-------------|
| X-Page | Current page number |
| X-Per-Page | Items per page (10) |
| X-Total | Total matching results |
| X-Total-Pages | Total pages |
| Link | RFC 5988 pagination links (preserves `q` and `workspace_id` parameters) |

### Error Responses

**Missing or empty query:**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Query parameter is required",
    "status": 422
  }
}
```

**Query too short (< 3 characters):**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Query must be at least 3 characters",
    "status": 422
  }
}
```

**Invalid FTS5 query syntax:**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid search query syntax",
    "status": 422
  }
}
```

**Authentication errors:** Standard 401/429 responses per existing API patterns.

**Workspace not found (when workspace_id filter used):**

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found",
    "status": 404
  }
}
```

## Implementation Plan

### 1. Add `api_search` scope to Searchable concern

**File:** `app/models/concerns/searchable.rb`

Add a new scope `api_search` that passes queries to FTS5 without quoting them as phrases, enabling full operator support. Includes error handling for invalid FTS5 syntax.

```ruby
scope :api_search, ->(query) {
  return none if query.blank? || query.length < MIN_QUERY_LENGTH

  joins("INNER JOIN memories_search ON memories_search.memory_id = memories.id")
    .where("memories_search MATCH ?", query)
    .order(Arel.sql("memories_search.rank"))
}
```

The existing `full_search` scope (used by HTML) remains unchanged — it continues to quote queries as phrases for safe browser-based search.

### 2. Update ApiHelpers pagination to preserve query params

**File:** `app/controllers/concerns/api_helpers.rb`

Update `pagination_link_header` to preserve query parameters (like `q`, `workspace_id`) in pagination Link header URLs.

### 3. Add SearchHelper with memory_snippet

**File:** `app/helpers/search_helper.rb`

Create helper with `memory_snippet(memory, length: 200)` that extracts plain text from memory content, strips markdown, and truncates.

### 4. Update SearchController for JSON API

**File:** `app/controllers/search_controller.rb`

Extend `index` action:
- JSON: validate query presence and minimum length (return 422 errors)
- JSON: use `api_search` scope (raw FTS5 operators) instead of `full_search` (phrase-quoted)
- JSON: rescue FTS5 syntax errors and return 422
- JSON: optional `workspace_id` filter
- JSON: set pagination headers
- JSON: allow up to 100 character queries (HTML stays at 30)
- HTML: behavior unchanged

### 5. Create Jbuilder JSON template

**File:** `app/views/search/index.json.jbuilder`

Render structured JSON with `query`, `total_results`, and `results` array.

### 6. Write tests

**File:** `test/controllers/api/search_test.rb`

### 7. Update documentation

**Files:** `docs/API.md`, `CLAUDE.md`

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `app/models/concerns/searchable.rb` | Modify | Add `api_search` scope with raw FTS5 operator support |
| `app/controllers/concerns/api_helpers.rb` | Modify | Preserve query params in pagination Link header |
| `app/helpers/search_helper.rb` | Create | `memory_snippet` helper for plain-text excerpts |
| `app/controllers/search_controller.rb` | Modify | Add JSON format handling, validation, workspace filter |
| `app/views/search/index.json.jbuilder` | Create | JSON response template |
| `test/controllers/api/search_test.rb` | Create | API search endpoint tests |
| `docs/API.md` | Modify | Add Search endpoint documentation |
| `CLAUDE.md` | Modify | Add search endpoint to API endpoints list |

## Out of Scope

- Search result highlighting (marking matched terms in snippets)
- Tag-only filtering parameter (could be added separately)
- Workspace-scoped nested search endpoints (the `workspace_id` parameter covers this)
- LIKE/GLOB operator support (FTS5 trigram supports these but MATCH is more appropriate for the API)
