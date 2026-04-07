# Recuerd0 API

The Recuerd0 API provides programmatic access to workspaces and memories. All responses are in JSON format.

## Authentication

All API requests require authentication via Bearer token and a JSON content type. Include these headers with every request:

```
Authorization: Bearer your_token_here
Content-Type: application/json
```

All responses use `Content-Type: application/json`.

### Token Permissions

- **read_only**: Can access GET endpoints only
- **full_access**: Can access all endpoints (GET, POST, PATCH, DELETE)

### Errors

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing access token",
    "status": 401
  }
}
```

## Rate Limiting

API requests are limited to 100 requests per minute per token. When exceeded:

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded. Please try again later.",
    "status": 429
  }
}
```

---

## Workspaces

### List Workspaces

Returns all active workspaces for the current account.

```
GET /workspaces.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| page | integer | Page number (default: 1) |

**Response**

```json
[
  {
    "id": 1,
    "name": "Project Alpha",
    "description": "Main project workspace",
    "memories_count": 42,
    "archived": false,
    "created_at": "2026-01-15T10:30:00Z",
    "updated_at": "2026-02-04T14:22:00Z",
    "url": "https://recuerd0.com/workspaces/1"
  }
]
```

**Headers**

| Header | Description |
|--------|-------------|
| X-Page | Current page number |
| X-Per-Page | Items per page |
| X-Total | Total item count |
| X-Total-Pages | Total pages |
| Link | Pagination links (first, prev, next, last) |

---

### Get Workspace

Returns a single workspace with memory count and pinned status.

```
GET /workspaces/:id.json
```

**Response**

```json
{
  "id": 1,
  "name": "Project Alpha",
  "description": "Main project workspace",
  "memories_count": 42,
  "archived": false,
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-02-04T14:22:00Z",
  "url": "https://recuerd0.com/workspaces/1"
}
```

---

### Get Workspace Context

Returns a compact "wake-up" snapshot of a workspace for AI agents to load in one call: workspace metadata, the current user's pinned memories scoped to the workspace, and stats. Supports HTTP caching via `ETag` / `If-None-Match`.

```
GET /workspaces/:id/context.json
```

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| limit | integer | 10 | Maximum pinned memories to return (1–50). |
| include_body | boolean | true | Whether to include each pinned memory's body content. |
| max_body_chars | integer | 500 | Maximum characters of body to return per memory (100–5000). Bodies longer than this are truncated with `…`. |

**Response** `200 OK`

```json
{
  "workspace": {
    "id": 1,
    "name": "Project Alpha",
    "description": "Main project workspace",
    "memories_count": 42,
    "state": "active",
    "updated_at": "2026-04-01T12:00:00Z",
    "url": "https://recuerd0.ai/workspaces/1"
  },
  "pinned_memories": [
    {
      "id": 17,
      "title": "Architecture Notes",
      "source": "manual",
      "tags": ["design", "core"],
      "pinned_at": "2026-03-28T09:14:00Z",
      "updated_at": "2026-04-01T11:42:00Z",
      "url": "https://recuerd0.ai/workspaces/1/memories/17",
      "body": "# Architecture\n\nThe system is split into…",
      "body_truncated": true
    }
  ],
  "stats": {
    "total_memories": 42,
    "total_pinned": 3,
    "returned_pinned": 1
  },
  "generated_at": "2026-04-06T10:00:00Z"
}
```

Returns `404 NOT_FOUND` if the workspace is deleted or does not belong to the authenticated account.

---

### Create Workspace

Creates a new workspace. Requires `full_access` token.

```
POST /workspaces.json
```

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| workspace[name] | string | Yes | Workspace name (max 100 characters) |
| workspace[description] | string | No | Workspace description |

**Request**

```json
{
  "workspace": {
    "name": "New Project",
    "description": "A new workspace for the team"
  }
}
```

**Response** `201 Created`

```json
{
  "id": 2,
  "name": "New Project",
  "description": "A new workspace for the team",
  "memories_count": 0,
  "archived": false,
  "created_at": "2026-02-04T15:00:00Z",
  "updated_at": "2026-02-04T15:00:00Z",
  "url": "https://recuerd0.com/workspaces/2"
}
```

**Errors**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Name can't be blank",
    "details": {
      "name": ["can't be blank"]
    },
    "status": 422
  }
}
```

---

### Update Workspace

Updates an existing workspace. Requires `full_access` token.

```
PATCH /workspaces/:id.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| workspace[name] | string | Workspace name |
| workspace[description] | string | Workspace description |

**Request**

```json
{
  "workspace": {
    "name": "Updated Name"
  }
}
```

**Response** `200 OK`

Returns the updated workspace object.

---

### Archive Workspace

Archives a workspace. Requires `full_access` token. Archived workspaces become read-only.

```
POST /workspaces/:id/archive.json
```

**Response** `200 OK`

Returns the updated workspace object with `archived: true`.

---

### Unarchive Workspace

Restores an archived workspace. Requires `full_access` token.

```
DELETE /workspaces/:id/archive.json
```

**Response** `200 OK`

Returns the updated workspace object with `archived: false`.

---

## Memories

### List Memories

Returns all memories (latest versions only) for a workspace. Supports filtering by title pattern, tags, and source.

```
GET /workspaces/:workspace_id/memories.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| page | integer | Page number (default: 1) |
| per_page | integer | Items per page (1-100, default: 25) |
| title | string | Glob pattern for title matching. `*` matches any characters, `?` matches a single character |
| tags | string | Comma-separated tag list. Returns memories containing ALL specified tags |
| source | string | Exact match on source field |
| sort | string | Sort field: `updated_at` (default), `created_at`, `title` |
| direction | string | Sort direction: `desc` (default), `asc` |

**Examples**

```
GET /workspaces/1/memories.json?title=Meeting*
GET /workspaces/1/memories.json?tags=api,design&sort=title&direction=asc
GET /workspaces/1/memories.json?source=claude-code-session&per_page=50
```

**Response**

```json
[
  {
    "id": 1,
    "title": "Meeting Notes",
    "version": 1,
    "source": "manual",
    "tags": ["meetings", "q1"],
    "created_at": "2026-01-20T09:00:00Z",
    "updated_at": "2026-02-03T16:45:00Z",
    "url": "https://recuerd0.com/workspaces/1/memories/1"
  }
]
```

**Headers**

Same pagination headers as workspace list.

---

### Browse Memories (Cross-Workspace)

Returns memories across all active workspaces for the current account. Supports the same filtering parameters as List Memories. JSON-only endpoint.

```
GET /memories.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| page | integer | Page number (default: 1) |
| per_page | integer | Items per page (1-100, default: 25) |
| workspace_id | integer | Filter to a specific workspace |
| title | string | Glob pattern for title matching. `*` matches any characters, `?` matches a single character |
| tags | string | Comma-separated tag list. Returns memories containing ALL specified tags |
| source | string | Exact match on source field |
| sort | string | Sort field: `updated_at` (default), `created_at`, `title` |
| direction | string | Sort direction: `desc` (default), `asc` |

**Examples**

```
GET /memories.json?title=*architecture*
GET /memories.json?tags=api,design&sort=title&direction=asc
GET /memories.json?workspace_id=1&source=manual
```

**Response**

Same format as List Memories. Each memory includes its workspace in the response. Only memories from active (non-archived, non-deleted) workspaces are returned.

**Headers**

Same pagination headers as other list endpoints.

---

### Get Memory

Returns a memory with its content. Supports line range parameters to read specific portions of the content.

```
GET /workspaces/:workspace_id/memories/:id.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| line_start | integer | First line to return (1-based, inclusive). Default: 1 |
| line_end | integer | Last line to return (1-based, inclusive). Default: last line |

**Examples**

```
GET /workspaces/1/memories/1.json
GET /workspaces/1/memories/1.json?line_start=1&line_end=20
GET /workspaces/1/memories/1.json?line_start=50&line_end=75
```

**Response**

```json
{
  "id": 1,
  "title": "Meeting Notes",
  "version": 1,
  "source": "manual",
  "tags": ["meetings", "q1"],
  "created_at": "2026-01-20T09:00:00Z",
  "updated_at": "2026-02-03T16:45:00Z",
  "url": "https://recuerd0.com/workspaces/1/memories/1",
  "content": {
    "body": "# Meeting Notes\n\nDiscussed Q1 goals...",
    "total_lines": 142,
    "line_start": 1,
    "line_end": 142
  },
  "workspace": {
    "id": 1,
    "name": "Project Alpha",
    "url": "https://recuerd0.com/workspaces/1"
  }
}
```

The `content` object always includes `total_lines`, `line_start`, and `line_end`. When line range parameters are provided, `body` contains only the requested lines and `line_start`/`line_end` reflect the actual range returned (clamped to content bounds).

**Errors**

Returns `422` if `line_start` is greater than `line_end`.

**Grep Mode**

When `mode=grep` is specified, the endpoint searches within the memory's content and returns matching lines with context instead of the full body.

Additional parameters (only with `mode=grep`):

| Name | Type | Required | Description |
|------|------|----------|-------------|
| q | string | Yes | Search query |
| context | integer | No | Lines before and after each match (0-10, default: 0) |
| before | integer | No | Lines before match, overrides context (0-10) |
| after | integer | No | Lines after match, overrides context (0-10) |

**Examples**

```
GET /workspaces/1/memories/1.json?mode=grep&q=architecture
GET /workspaces/1/memories/1.json?mode=grep&q=design&context=2
GET /workspaces/1/memories/1.json?mode=grep&q=TODO&before=0&after=5
```

**Response**

```json
{
  "id": 1,
  "title": "Meeting Notes",
  ...
  "content": {
    "total_lines": 142,
    "matches": [
      {
        "line_number": 12,
        "line": "Discussed architecture decisions.",
        "context_before": ["## Design"],
        "context_after": ["The team agreed on microservices."]
      }
    ]
  }
}
```

Returns `422` if `q` parameter is missing when `mode=grep`.

---

### Create Memory

Creates a new memory with content. Requires `full_access` token.

```
POST /workspaces/:workspace_id/memories.json
```

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| memory[title] | string | No | Memory title (max 255 characters) |
| memory[content] | string | No | Memory body (Markdown) |
| memory[source] | string | No | Source identifier |
| memory[tags] | array | No | Array of tag strings |

**Request**

```json
{
  "memory": {
    "title": "API Documentation",
    "content": "# Overview\n\nThis document describes...",
    "tags": ["docs", "api"]
  }
}
```

**Response** `201 Created`

Returns the created memory object with content.

---

### Update Memory

Updates an existing memory. Requires `full_access` token.

```
PATCH /workspaces/:workspace_id/memories/:id.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| memory[title] | string | Memory title |
| memory[content] | string | Memory body |
| memory[source] | string | Source identifier |
| memory[tags] | array | Array of tags |

**Response** `200 OK`

Returns the updated memory object with content.

---

### Delete Memory

Deletes a memory and all its versions. Requires `full_access` token.

```
DELETE /workspaces/:workspace_id/memories/:id.json
```

**Response** `204 No Content`

---

## Memory Versions

### Create Version

Creates a new version of a memory. Requires `full_access` token.

```
POST /workspaces/:workspace_id/memories/:memory_id/versions.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| version[title] | string | Version title (defaults to parent) |
| version[content] | string | Version body (defaults to parent) |
| version[source] | string | Source identifier (defaults to parent) |
| version[tags] | array | Tags (defaults to parent) |

**Request**

```json
{
  "version": {
    "content": "# Updated Content\n\nRevised version..."
  }
}
```

**Response** `201 Created`

```json
{
  "id": 5,
  "title": "Meeting Notes",
  "version": 2,
  "source": "manual",
  "tags": ["meetings", "q1"],
  "created_at": "2026-02-04T16:00:00Z",
  "updated_at": "2026-02-04T16:00:00Z",
  "url": "https://recuerd0.com/workspaces/1/memories/5",
  "content": {
    "body": "# Updated Content\n\nRevised version..."
  },
  "workspace": {
    "id": 1,
    "name": "Project Alpha",
    "url": "https://recuerd0.com/workspaces/1"
  }
}
```

---

## Search

### Search Memories

Full-text search across all memories in active workspaces. Supports FTS5 query operators for advanced search patterns. Requires `read_only` or `full_access` token.

```
GET /search.json?q=<query>
```

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| q | string | Yes | Search query (3-100 characters) |
| page | integer | No | Page number (default: 1) |
| workspace_id | integer | No | Filter results to a specific workspace |
| mode | string | No | Response mode: `snippet` (default) or `grep` |
| context | integer | No | Lines of context around each match, like `grep -C` (0-10, default: 0). Only used with `mode=grep` |
| before | integer | No | Lines before each match, like `grep -B` (0-10). Overrides `context` for before. Only used with `mode=grep` |
| after | integer | No | Lines after each match, like `grep -A` (0-10). Overrides `context` for after. Only used with `mode=grep` |

**Query Operators**

The search query supports full FTS5 syntax:

| Operator | Example | Description |
|----------|---------|-------------|
| Term | `architecture` | Matches documents containing the substring |
| AND | `architecture AND design` | Both terms must appear |
| OR | `meeting OR standup` | Either term can appear |
| NOT | `design NOT draft` | First term must appear, second must not |
| Phrase | `"project timeline"` | Exact phrase match |
| Column filter | `title:architecture` | Search only in title field |
| Column filter | `body:implementation` | Search only in body field |
| Grouping | `(meeting OR standup) AND notes` | Parentheses for precedence |

**Response (snippet mode — default)**

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

**Response (grep mode)**

When `mode=grep`, each result includes `matches` (line-level matches with context) and `total_lines` instead of `snippet`:

```json
{
  "query": "architecture",
  "total_results": 2,
  "results": [
    {
      "id": 1,
      "title": "Design Doc",
      "version": 1,
      "version_label": "v1",
      "has_versions": false,
      "tags": ["design"],
      "source": "manual",
      "total_lines": 45,
      "matches": [
        {
          "line_number": 12,
          "line": "The architecture uses a layered approach with clear boundaries.",
          "context_before": ["", "## System Design"],
          "context_after": ["Each layer communicates through well-defined interfaces."]
        },
        {
          "line_number": 28,
          "line": "Updated the architecture diagram to reflect new services.",
          "context_before": ["### Changes"],
          "context_after": [""]
        }
      ],
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

**Examples**

```
GET /search.json?q=architecture&mode=grep&context=2
GET /search.json?q=meeting AND notes&mode=grep&before=0&after=3
GET /search.json?q=title:design&workspace_id=1
```

**Headers**

Same pagination headers as other list endpoints. Pagination links preserve the `q` parameter.

**Errors**

Missing or empty query:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Query parameter is required",
    "status": 422
  }
}
```

Query too short:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Query must be at least 3 characters",
    "status": 422
  }
}
```

Invalid FTS5 syntax:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid search query syntax",
    "status": 422
  }
}
```

---

## Common Errors

### 401 Unauthorized

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing access token",
    "status": 401
  }
}
```

### 403 Forbidden

Returned when using a `read_only` token for write operations:

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Insufficient permissions",
    "status": 403
  }
}
```

Or when accessing an inactive workspace:

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Workspace is not active",
    "status": 403
  }
}
```

### 404 Not Found

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found",
    "status": 404
  }
}
```

### 422 Unprocessable Entity

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Name can't be blank",
    "details": {
      "name": ["can't be blank"]
    },
    "status": 422
  }
}
```

### 429 Too Many Requests

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded. Please try again later.",
    "status": 429
  }
}
```
