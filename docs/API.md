# Recuerd0 API

The Recuerd0 API provides programmatic access to workspaces and memories. All responses are in JSON format.

## Authentication

All API requests require authentication via Bearer token. The scheme name is case-insensitive. Requests with a body also need a JSON content type:

```
Authorization: Bearer your_token_here
Content-Type: application/json
```

All responses use `Content-Type: application/json`. On a self-hosted instance, use that instance's own address as the base URL.

### Token Permissions

- **read_only**: Can access GET endpoints only
- **full_access**: Can access all endpoints (GET, POST, PATCH, DELETE)

### Token scope

A token acts as the user who created it, across every workspace in that
account. There is no per-workspace token — mint the token from the user whose
reach you want the caller to have.

- Workspaces, memories and search results in **other accounts** answer `404`,
  byte for byte the same response a non-existent id gets. The 404 is
  deliberate: a `403` would confirm the record exists.
- **read_only** tokens are refused with `403` on every non-GET request, in every
  format — there is no endpoint where a read-only token can write.
- A **refresh token is bound to the OAuth client it was issued to**: `POST /oauth/token`
  with `grant_type=refresh_token` requires the matching `client_id`, and a missing or
  mismatched one answers `invalid_grant` (`400`) exactly as an unknown token does.
- Tokens work on the API surface only. The profile, password, account and OAuth
  consent pages are browser-only and answer `401` to a token, however valid, so
  a token can never manage its owner's credentials or mint another token.

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

Every error under an API path uses this format, including unknown paths and bad requests. See [Common Errors](#common-errors) for each code.

## Rate Limiting

API requests are limited to 100 requests per minute per token. When exceeded, the response carries a `Retry-After: 60` header:

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests",
    "status": 429
  }
}
```

## Pagination

List endpoints take `page` (default 1) and report their position in `X-Page`, `X-Per-Page`, `X-Total`, `X-Total-Pages` and `Link` headers.

- A `page` past the end returns an empty list, so a client can loop until it gets one.
- A `page` that isn't a positive integer (`0`, `-1`, `abc`) is a `422`.

## Size limits

| Field | Limit |
|---|---|
| `workspace[name]` | 100 characters |
| `workspace[description]` | 500 characters |
| `memory[title]` | 255 characters |
| `memory[content]` | 1 MB |
| `memory[source]` | 255 characters |
| `memory[tags]` | 50 tags, each up to 100 characters |

Going over a limit is a `422` naming the field. Limits apply when a value changes, so an older row over a limit can still be edited in other ways.

---


## Hidden memories

Two kinds of memory are withheld from retrieval by default, each behind its own
`include` token. Tokens compose in any order (`include=obsolete,inactive`), and the
search form's checkboxes submit them as a repeated param (`include=obsolete&include=inactive`),
which is accepted too.

### Obsolete memories (`include=obsolete`)

A memory tagged `obsolete`, `superseded` or `deprecated` (case-insensitive, whole-tag —
`deprecated-api` is an ordinary tag) is retired knowledge. It is **excluded by default**
from search, listings, workspace context, stats and merge candidates, so a caller loading
context is never woken on a decision that was reversed.

Pass `include=obsolete` on any of those endpoints to get them back. Unrecognized tokens
are ignored: `include=obsolete,future_token` behaves exactly as `include=obsolete`. The
flag is required even when filtering explicitly for the tag — `GET /memories.json?tags=obsolete`
returns nothing without it.

Fetching by identity is never filtered: `GET /memories.json?ids=1,2,3` returns obsolete
memories with no flag, as do the `read_memory` / `read_memories` MCP tools. Browsing a
workspace in the UI is also unfiltered; obsolete tags are simply shown as such.

`GET /search.json` reports what it withheld in `obsolete_hidden` (`0` when nothing was
hidden, and always `0` when `include=obsolete` is passed).

One exception worth knowing: `stats.total_memories` on `GET /workspaces/:id/context.json`
is the workspace's total memory count and does not change with `include`. The memories it
returns, and `stats.total_pinned`, do. `GET /workspaces/:id/stats.json` filters every
figure it reports.

MCP tools take `include` as an array of strings (`include: ["obsolete"]`); any other
token, or a non-array value, is a JSON-RPC error.

### Inactive workspaces (`include=inactive`)

A workspace is **inactive** once it is archived or soft-deleted. Its memories are
**excluded by default** from `GET /search.json`, `GET /search` (HTML) and
`GET /memories/pinned.json`, so an agent waking up on an account never acts on a project
that was shut down. Pass `include=inactive` to review them deliberately; the payload's
`workspace.state` says which kind each one came from.

`GET /search.json` reports what this filter withheld in `inactive_hidden`, beside
`obsolete_hidden`. The two counts describe **disjoint** sets: a memory that is both
obsolete and in an inactive workspace is counted only under `obsolete_hidden`.

`inactive` is REST-only. MCP tools accept `include: ["obsolete"]` and nothing else: MCP
listings are already workspace-scoped and active-only, and there is no cross-workspace MCP
search.

### Deleted workspaces answer 404

A **soft-deleted** workspace's JSON resources are unreachable by id until the workspace is
restored — deletion means what the confirmation dialog promised:

| Surface | Behaviour |
|---|---|
| `GET/PATCH/DELETE /workspaces/:id[.json]` | `404` with the `NOT_FOUND` envelope |
| `POST/DELETE /workspaces/:id/archive[.json]` | `404` |
| `GET/POST/PATCH/DELETE /workspaces/:id/memories[/:id][.json]` | `404` with the `NOT_FOUND` envelope |
| `GET/POST /workspaces/:id/memories/:id/versions.json` | `404` |
| `GET/POST/DELETE /workspaces/:id/memories/:id/links[.json]` | `404` |
| `GET /workspaces/:id/context.json`, `stats.json`, `merge_candidates.json` | `404` (unchanged) |
| MCP `read_memory`, `update_memory`, `list_memory_links`, `link_memories`, `unlink_memories` | `Memory not found` |
| MCP `read_memories` | the id is listed under `missing` |
| `GET /workspaces/:id/export.json` | **still exported** — it is the recovery dump |

Links never resolve to a memory in a deleted workspace, in either direction.

`GET /search.json?include=inactive` is the one read that still lists a deleted workspace's
memories, so you can review them. Check each result's `workspace.state`: while it says
`deleted`, the result's `url` answers `404`.

**Archived** workspaces are different: every endpoint above stays readable, writes still
answer `403` (links included), and only `workspace.state` changes.

### Unknown `category` is a 422

A non-blank `category` outside the four values is rejected rather than silently ignored, so
a typo can never be mistaken for a filtered result. Applies to `GET /workspaces/:id/memories.json`,
`GET /memories.json`, `GET /search.json` and `GET /workspaces/:id/context.json`:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Invalid category: bogus", "status": 422 } }
```

A blank value still means "no filter". HTML pages keep ignoring an unknown category.

### Memory status fields

Every memory payload states its own status, so a client can gate context injection without
parsing tags or comparing version numbers:

| Field | Meaning |
|---|---|
| `obsolete` | the memory carries an obsolete/superseded/deprecated tag |
| `current` | this row is the live version (`false` on a historical version read) |
| `root_id` | the id of the memory's root row — what to fetch to get the live version |
| `workspace.state` | `active`, `archived` or `deleted` |

MCP's `memory_json` carries `obsolete` and `current`; its `id` is already the root id.

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
    "state": "active",
    "created_at": "2026-01-15T10:30:00Z",
    "updated_at": "2026-02-04T14:22:00Z",
    "url": "https://recuerd0.com/workspaces/1",
    "pinned": false,
    "pinned_at": null,
    "pin_origin": null
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

Returns a single workspace with memory count, state and pinned status. `state` is `active` or `archived`; a deleted workspace answers `404`.

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
  "state": "active",
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-02-04T14:22:00Z",
  "url": "https://recuerd0.com/workspaces/1",
  "pinned": true,
  "pinned_at": "2026-02-01T09:00:00Z",
  "pin_origin": "user"
}
```

---

### Get Workspace Context

Returns a compact "wake-up" snapshot of a workspace for AI agents to load in one call: workspace metadata, a small set of orienting memories, and stats. Supports HTTP caching via `ETag` / `If-None-Match`.

Which memories you get depends on the requesting user's pins in the workspace:

| Pins | Memories returned | `context_source` |
|---|---|---|
| Any they chose | Their pinned memories | `pins` |
| Only ones recuerd0 placed, such as the seeded Map | Those first, then the workspace's most recently updated memories, up to `limit` | `recent`, or `pins` if the workspace holds nothing else |
| None | The most recently updated memories | `recent` |

```
GET /workspaces/:id/context.json
```

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| limit | integer | 10 | Maximum memories to return (1–50). |
| include_body | boolean | true | Whether to include each memory's body content. |
| max_body_chars | integer | 500 | Maximum characters of body to return per memory (100–5000). Bodies longer than this are truncated with `…`. |
| category | string | — | Filter memories to a single category (`decision`, `discovery`, `preference`, `general`). Any other non-blank value is a `422`. |
| include | string | — | Comma-separated tokens re-enabling hidden memories. `obsolete` and (on search and pinned) `inactive` are recognized; unknown tokens are ignored. See [Hidden memories](#hidden-memories). |

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
  "memories": [
    {
      "id": 17,
      "title": "Architecture Notes",
      "source": "manual",
      "tags": ["design", "core"],
      "category": "decision",
      "pinned_at": "2026-03-28T09:14:00Z",
      "updated_at": "2026-04-01T11:42:00Z",
      "url": "https://recuerd0.ai/workspaces/1/memories/17",
      "body": "# Architecture\n\nThe system is split into…",
      "body_truncated": true
    }
  ],
  "context_source": "pins",
  "stats": {
    "total_memories": 42,
    "total_pinned": 3,
    "returned": 1,
    "returned_pinned": 1
  },
  "generated_at": "2026-04-06T10:00:00Z"
}
```

The `pinned_memories` array and `stats.returned_pinned` remain as deprecated aliases of `memories` and `stats.returned`.

Returns `404 NOT_FOUND` if the workspace is deleted or does not belong to the authenticated account.

---

### Create Workspace

Creates a new workspace. Requires `full_access` token.

A new workspace starts with a seeded, auto-pinned **Map** memory explaining how to use it, so `memories_count` is `1`. Pass `start_with_map: false` to start empty. The `Location` header holds the new workspace's URL.

```
POST /workspaces.json
```

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| workspace[name] | string | Yes | Workspace name (max 100 characters) |
| workspace[description] | string | No | Workspace description (max 500 characters) |
| workspace[start_with_map] | boolean | No | `false` skips the seeded Map (default: `true`) |

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
  "memories_count": 1,
  "archived": false,
  "state": "active",
  "created_at": "2026-02-04T15:00:00Z",
  "updated_at": "2026-02-04T15:00:00Z",
  "url": "https://recuerd0.com/workspaces/2",
  "pinned": false,
  "pinned_at": null,
  "pin_origin": null
}
```

**Errors**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Give your workspace a name so you can find it later.",
    "details": {
      "name": ["Give your workspace a name so you can find it later."]
    },
    "status": 422
  }
}
```

---

### Update Workspace

Updates an existing workspace. Requires `full_access` token, and the token's owner must own it or be an account admin; otherwise `403 FORBIDDEN`.

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

### Delete Workspace

Soft-deletes a workspace and everything in it. Requires `full_access` token.

```
DELETE /workspaces/:id.json
```

**Response** `204 No Content`

From then on, the workspace and its memories answer `404` over the API. See [Deleted workspaces answer 404](#deleted-workspaces-answer-404). `GET /workspaces/:id/export.json` keeps working, so you can still take a copy.

A deleted workspace stays recoverable for 30 days. **Restoring is browser-only:** an account member does it from the Deleted Workspaces page in the web app, and there is no REST endpoint for it.

---

### Archive Workspace

Archives a workspace. Requires `full_access` token, and the token's owner must own it or be an account admin; otherwise `403 FORBIDDEN`. Archived workspaces become read-only.

```
POST /workspaces/:id/archive.json
```

**Response** `200 OK`

Returns the updated workspace object with `archived: true`.

---

### Export Workspace

Returns every memory in a workspace, with all its versions, as one JSON document. Requires `read_only` or `full_access` token. Available at any time and not subject to the monthly limit on full account exports.

```
GET /workspaces/:id/export.json
```

---

### Unarchive Workspace

Restores an archived workspace. Requires `full_access` token.

```
DELETE /workspaces/:id/archive.json
```

**Response** `200 OK`

Returns the updated workspace object with `archived: false`.

---

### Get Workspace Stats

Returns an aggregate rollup for a workspace, computed server-side, without shipping memory bodies. Use this instead of paging the full memory list when you only need counts or trends. JSON-only endpoint.

```
GET /workspaces/:workspace_id/stats.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| include | string | Comma-separated tokens re-enabling hidden memories. `obsolete` and (on search and pinned) `inactive` are recognized; unknown tokens are ignored. See [Hidden memories](#hidden-memories). |

**Response** `200 OK`

```json
{
  "workspace": { "id": 1, "name": "Engineering", "url": "https://…/workspaces/1" },
  "total_memories": 495,
  "total_versions": 631,
  "total_links": 42,
  "counts_by_category": { "decision": 120, "discovery": 88, "preference": 15, "general": 272 },
  "top_tags": [ { "tag": "api", "count": 37 }, { "tag": "design", "count": 21 } ],
  "memories_by_week": { "2026-18": 12, "2026-19": 9 },
  "generated_at": "2026-07-15T12:00:00Z"
}
```

- `total_memories` counts current memories (latest versions); `total_versions` counts every version row.
- `counts_by_category` always includes all four categories (zero-filled). Counts reflect each memory's **current version** category.
- `memories_by_week` is keyed by ISO `year-week` of creation.

---

### Get Merge Candidates

Returns clusters of likely-duplicate memories, scored by shared tags and title similarity. **Read-only suggestions** — merging remains a manual action; this endpoint only proposes clusters. JSON-only endpoint.

```
GET /workspaces/:workspace_id/merge_candidates.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| min_score | number | Similarity threshold `0`–`1` (default `0.5`). Higher = stricter |
| include | string | Comma-separated tokens re-enabling hidden memories. `obsolete` and (on search and pinned) `inactive` are recognized; unknown tokens are ignored. See [Hidden memories](#hidden-memories). |

**Response** `200 OK`

```json
{
  "workspace": { "id": 1, "name": "Engineering", "url": "https://…/workspaces/1" },
  "candidates": [
    {
      "score": 0.82,
      "reasons": ["similar title", "shared tags"],
      "memories": [
        { "id": 12, "title": "Deploy runbook", "category": "general", "tags": ["ops"], "source": "manual", "version": 1, "updated_at": "…", "url": "…" },
        { "id": 47, "title": "Deploy runbook", "category": "general", "tags": ["ops"], "source": "Claude", "version": 2, "updated_at": "…", "url": "…" }
      ]
    }
  ],
  "generated_at": "2026-07-15T12:00:00Z"
}
```

---

## Memories

### Memory Categories

Every memory belongs to exactly one category. The set is fixed:

| Value | Purpose |
|-------|---------|
| `decision` | Architecture choices, library picks, tradeoffs with stated reasoning |
| `discovery` | Non-obvious findings — gotchas, root causes, patterns, library quirks |
| `preference` | User-stated rules ("always X", "never Y") |
| `general` | Catch-all and default |

New memories default to `general` when no category is specified. The list, browse, search, and context endpoints all accept `?category=<value>` to filter results.

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
| title | string | Glob pattern for title matching. `*` matches any characters, `?` matches a single character. Every other character, including `%` and `_`, means itself |
| tags | string | Comma-separated tag list, ignoring case. Returns memories containing ALL specified tags. A tag that itself contains a comma can't be filtered on |
| source | string | Exact match on source field |
| category | string | Filter by category (`decision`, `discovery`, `preference`, `general`) |
| sort | string | Sort field: `updated_at` (default), `created_at`, `title` |
| direction | string | Sort direction: `desc` (default), `asc` |
| include | string | Comma-separated tokens re-enabling hidden memories. `obsolete` and (on search and pinned) `inactive` are recognized; unknown tokens are ignored. See [Hidden memories](#hidden-memories). |

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
    "tags": ["meetings", "q1"],
    "source": "manual",
    "category": "general",
    "version": 1,
    "version_label": "v1",
    "has_versions": false,
    "obsolete": false,
    "current": true,
    "root_id": 1,
    "links_count": 0,
    "created_at": "2026-01-20T09:00:00Z",
    "updated_at": "2026-02-03T16:45:00Z",
    "url": "https://recuerd0.com/workspaces/1/memories/1",
    "workspace": {
      "id": 1,
      "name": "Project Alpha",
      "state": "active",
      "url": "https://recuerd0.com/workspaces/1"
    },
    "pinned": false,
    "pinned_at": null,
    "pin_origin": null
  }
]
```

Get Memory, Browse Memories and the version endpoints return these same fields. Search, context and links return their own shapes, shown in their sections. Each new version gets its own `id`, while `root_id` stays the same, so `root_id` is the one to store if you want to refer to the memory across saves.

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
| ids | string | Comma-separated memory IDs. Batch-fetches exactly those memories (still account-scoped and paginated). An old version's ID returns its memory, as the current version |
| title | string | Glob pattern for title matching. `*` matches any characters, `?` matches a single character. Every other character, including `%` and `_`, means itself |
| tags | string | Comma-separated tag list, ignoring case. Returns memories containing ALL specified tags. A tag that itself contains a comma can't be filtered on |
| source | string | Exact match on source field |
| category | string | Filter by category (`decision`, `discovery`, `preference`, `general`) |
| sort | string | Sort field: `updated_at` (default), `created_at`, `title` |
| direction | string | Sort direction: `desc` (default), `asc` |
| include | string | Comma-separated tokens re-enabling hidden memories. `obsolete` and (on search and pinned) `inactive` are recognized; unknown tokens are ignored. See [Hidden memories](#hidden-memories). |

**Examples**

```
GET /memories.json?title=*architecture*
GET /memories.json?tags=api,design&sort=title&direction=asc
GET /memories.json?workspace_id=1&source=manual
GET /memories.json?ids=12,34,56
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
  "category": "general",
  "obsolete": false,
  "current": true,
  "root_id": 1,
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

The `content` object always includes `total_lines`, `line_start`, and `line_end`. When line range parameters are provided, `body` contains only the requested lines and `line_start`/`line_end` reflect the actual range returned (clamped to content bounds). A `line_start` past the last line returns an empty `body`, because a memory can shrink between two reads.

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

**Workflow: grep, then fetch a window**

For large memories, prefer a two-step pattern over loading the full body: call grep mode first to find the `line_number` of each match, then call again with `line_start`/`line_end` to fetch a window of surrounding context.

```
# 1. Find matches and their line numbers
GET /workspaces/1/memories/1.json?mode=grep&q=TODO
```

```json
{
  "content": {
    "total_lines": 412,
    "matches": [
      { "line_number": 47, "line": "TODO: revisit caching", "context_before": [], "context_after": [] }
    ]
  }
}
```

```
# 2. Fetch a 16-line window around line 47
GET /workspaces/1/memories/1.json?line_start=40&line_end=55
```

Because `total_lines` is echoed on every response (both modes), clients can compute a "tail" of the last `N` lines without an extra round trip:

```
GET /workspaces/1/memories/1.json?line_start=(total_lines - N + 1)&line_end=total_lines
```

There is no `head=` or `tail=` query parameter — head and tail are expressed as `line_start=1&line_end=N` and `line_start=(total_lines - N + 1)&line_end=total_lines`, respectively.

---

### Create Memory

Creates a new memory with content. Requires `full_access` token. A memory needs a title or some content: with neither, the response is `422`.

```
POST /workspaces/:workspace_id/memories.json
```

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| memory[title] | string | No | Memory title (max 255 characters) |
| memory[content] | string | No | Memory body (Markdown, max 1 MB) |
| memory[source] | string | No | Source identifier (max 255 characters) |
| memory[tags] | array | No | Array of tag strings (max 50 tags, 100 characters each) |
| memory[category] | string | No | One of `decision`, `discovery`, `preference`, `general` (default: `general`) |

A field of the wrong type, such as `"tags": "one,two"` or `"content": ["a", "b"]`, is a `422` naming it, on this endpoint and on Update Memory and Create Version. So is text containing a null character, and a `memory` object that is missing or empty.

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

Returns the created memory object with content. The `Location` header holds its URL.

---

### Update Memory

Updates an existing memory in place. Requires `full_access` token, and the token's owner must own the memory or be an account admin; otherwise `403 FORBIDDEN`. Anyone else can add a version instead.

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
| memory[category] | string | One of `decision`, `discovery`, `preference`, `general` |

**Response** `200 OK`

Returns the updated memory object with content.

---

### Delete Memory

Deletes a memory and all its versions. Requires `full_access` token, and the token's owner must own the memory, own its workspace, or be an account admin; otherwise `403 FORBIDDEN`.

`:id` is the memory's root id or its current version's id. An older version's id returns `422` and deletes nothing, because versions can't be deleted one by one here: use `root_id` from the response, or purge old versions from the web.

```
DELETE /workspaces/:workspace_id/memories/:id.json
```

**Response** `204 No Content`

---

### List Pinned Memories

Returns the current user's pinned memories across all workspaces. Requires `read_only` or `full_access` token. The list isn't paginated, because the number of pins a user can have is capped.

```
GET /memories/pinned.json
GET /memories/pinned.json?include=obsolete,inactive
```

**Query Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| include | string | Comma-separated tokens re-enabling hidden pins: `obsolete`, `inactive`. See [Hidden memories](#hidden-memories). |

**Response** `200 OK` — an array of memory objects (same shape as List Memories).

Obsolete pins and pins in archived or deleted workspaces are withheld by default. The
pinned **page** still shows every pin, including the group it labels "Inactive" — curation
is not retrieval.

---

## Ownership

Workspaces and memories report an `owner_id`: the user who answers for them. It starts as whoever created the record and can be passed on. `null` means the account admin.

### Pass or Take Ownership

Requires `full_access` token. The owner can pass a record to anyone still on the account. An admin who doesn't own it can only name themselves, and can pass it on once they do. Anyone else gets `403 FORBIDDEN`. The receiver doesn't have to accept. Passing a workspace moves the workspace only: the memories in it keep their owners.

```
PATCH /workspaces/:id/ownership.json
PATCH /workspaces/:workspace_id/memories/:id/ownership.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| user_id | integer | Who receives it (required) |

**Response** `200 OK`

```json
{"id": 12, "owner_id": 7}
```

A `user_id` that isn't on the account, or that already owns the record, returns `422`. A deleted workspace returns `404`, and a memory in an archived workspace `403`.

---

## Memory Links

Cross-workspace "see also" connections between two memories within the same account. Links are **undirected** and **unlabeled** — they're just a set-style relationship. Internally a link is stored once with a normalized order (smaller memory id in `from_memory_id`), but callers don't need to care: querying or deleting works from either side.

Memory and workspace context responses include a `links_count` integer field on each memory so clients can know whether links exist without fetching the full list.

### List Memory Links

Returns the memories linked to a given memory. Latest versions only, ordered by `updated_at` desc.

```
GET /workspaces/:workspace_id/memories/:memory_id/links.json
```

**Response** `200 OK`

```json
[
  {
    "id": 42,
    "title": "Prompt Engineering Best Practices",
    "category": "preference",
    "tags": ["prompt-engineering"],
    "source": "Claude discussion",
    "updated_at": "2026-04-07T00:01:23Z",
    "url": "https://example.com/workspaces/3/memories/42",
    "workspace": {
      "id": 3,
      "name": "AI Research Notes",
      "url": "https://example.com/workspaces/3"
    }
  }
]
```

Supports `If-None-Match` / `If-Modified-Since` for `304 Not Modified` responses.

### Create Memory Link

Creates an undirected link between `:memory_id` and another memory in the same account. Requires `full_access` token.

```
POST /workspaces/:workspace_id/memories/:memory_id/links.json
```

**Body**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `to_memory_id` | integer | yes | Id of the other memory. Must belong to the same account. May live in any workspace. |

**Response** `201 Created` — same shape as one element of the list response, returning the *other* memory.

**Errors**

- `422 VALIDATION_ERROR` — `to_memory_id` is missing, equals `:memory_id` (self-link), references a memory in another account, or the link already exists (in either direction).
- `403 FORBIDDEN` — token lacks `full_access`, or either memory is in an archived workspace.
- `404 NOT_FOUND` — `:workspace_id` or `:memory_id` is not visible to the current account.

### Delete Memory Link

Removes the link between `:memory_id` and the memory identified by `:id`. The URL `:id` is the **other memory's id**, NOT a `MemoryLink` row id — the server resolves the join row internally so clients never need to track it. Requires `full_access` token.

Only an admin or the person who created the link can remove it. A link with no recorded creator belongs to the admin. The MCP `unlink_memories` tool follows the same rule.

```
DELETE /workspaces/:workspace_id/memories/:memory_id/links/:id.json
```

**Response** `204 No Content`

**Errors**

- `404 NOT_FOUND` — no such link exists, or the other memory is not visible to the current account.
- `403 FORBIDDEN` — token lacks `full_access`, the caller is a member who didn't create the link, or either memory is in an archived workspace.

---

## Memory Versions

### List Versions

Lists every version of a memory, oldest to newest. Requires `read_only` or `full_access` token.

```
GET /workspaces/:workspace_id/memories/:memory_id/versions.json
```

**Response** `200 OK` — an array of memory objects (same shape as List Memories, without the pin fields), one per version. `:memory_id` can be any version's id.

---

### Get Version

Returns a single version with its content.

```
GET /workspaces/:workspace_id/memories/:memory_id/versions/:id.json
```

**Response** `200 OK` — a memory object with its `content` (same shape as Get Memory).

---

### Create Version

Creates a new version of a memory. Requires `full_access` token. Omitted fields come from its current version, or from the version whose id is in the URL. A result identical to the current version is refused with `422`; a `change_note` alone is not a change. Anyone in the account can do this; updating a memory in place (`PATCH`) needs its creator or an account admin, otherwise `403 FORBIDDEN`.

```
POST /workspaces/:workspace_id/memories/:memory_id/versions.json
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| version[title] | string | Version title (defaults to the current version) |
| version[content] | string | Version body (defaults to the current version) |
| version[source] | string | Source identifier (defaults to the current version) |
| version[tags] | array | Tags (defaults to the current version) |
| version[category] | string | Category (defaults to the current version) |
| version[change_note] | string | Why this version exists, in one line (optional, max 280 characters) |

Leaving `content` out inherits it. Sending it blank is a `422`, the same as Update Memory, because it would wipe the memory's current text.

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
  "category": "general",
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

REST `GET /search.json`, the web UI and MCP `list_memories` share one search
contract (`Memory.search`), so the same query returns the same memories, in the same
order, everywhere. Only the scope differs: REST and the web search page span the
account (optionally one workspace), MCP and the workspace filter search one workspace.

- Whitespace is trimmed once.
- Queries of three or more characters run FTS over memory titles and bodies with the
  [operators below](#query-operators), unioned with case-insensitive whole-tag
  equality. Words are ANDed.
- Every bare word is quoted before it reaches FTS5, so punctuation inside a word is
  searched literally (`deploy.sh`, `maquina-components`). An expression whose
  operators do not parse (`kamal OR`, `(sqlite`) is searched as its words ANDed —
  search never fails on syntax.
- Matching is substring-level (trigram tokenizer): a word can match inside longer
  words — `rank` matches `ranking`. A trailing `*` is accepted and ignored.
- An unquoted word under three characters can't be searched, so it is left out and the
  rest of the query still matches: `how to deploy` searches `how` and `deploy`. REST and
  MCP name what was left out in `ignored_words`, and the web says so under the search
  field. A quoted phrase stays exact.
- FTS matches come first by rank. A memory that also has the exact tag appears once
  in the FTS group. Tag-only matches follow by `updated_at DESC`, with stable
  memory-ID tie-breakers so pagination is deterministic.
- The index holds each memory's current version, and every result is returned as its
  current version — title, version, snippet and grep lines are never an older one.
- **Related memories.** When the server runs with `HYBRID_RETRIEVAL=true` and a query
  finds fewer than three keyword matches, up to five memories close in meaning (local
  MiniLM embeddings, cosine similarity ≥ 0.33) follow the keyword matches on the first
  page. Keyword matches are never reordered. Every search result carries
  `match: "keyword"` or `match: "related"`; related results add `similarity` and
  don't contain the query words. `total_results` / `total_count` count keyword matches
  only; `related_results` / `related_count` count the related ones.

### REST: `GET /search.json`

Full-text search across all memories in active workspaces. Requires at least three
characters and a `read_only` or `full_access` token.

```
GET /search.json?q=<query>
```

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| q | string | Yes | Search query (3-100 characters) |
| page | integer | No | Page number (default: 1) |
| workspace_id | integer | No | Filter results to a specific workspace |
| category | string | No | Filter results by category (`decision`, `discovery`, `preference`, `general`) |
| mode | string | No | Response mode: `snippet` (default) or `grep` |
| context | integer | No | Lines of context around each match, like `grep -C` (0-10, default: 0). Only used with `mode=grep` |
| before | integer | No | Lines before each match, like `grep -B` (0-10). Overrides `context` for before. Only used with `mode=grep` |
| after | integer | No | Lines after each match, like `grep -A` (0-10). Overrides `context` for after. Only used with `mode=grep` |
| include | string | No | Comma-separated tokens re-enabling hidden memories. `obsolete` and (on search and pinned) `inactive` are recognized; unknown tokens are ignored. See [Hidden memories](#hidden-memories). |

<a id="query-operators"></a>
**Query Operators**

The search query supports FTS5 operators:

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

Unquoted words under three characters can't be searched, so they are left out and the rest of the query still matches. `how to deploy` searches `how` and `deploy`, and the response lists `to` in `ignored_words`. A quoted phrase stays exact.

**Response (snippet mode — default)**

```json
{
  "query": "architecture AND design",
  "ignored_words": [],
  "total_results": 3,
  "related_results": 0,
  "obsolete_hidden": 1,
  "inactive_hidden": 2,
  "results": [
    {
      "id": 1,
      "title": "Design Doc",
      "version": 1,
      "version_label": "v1",
      "has_versions": false,
      "tags": ["design"],
      "source": "manual",
      "category": "decision",
      "match": "keyword",
      "snippet": "Initial architecture overview. The system uses a layered design...",
      "created_at": "2026-01-20T09:00:00Z",
      "updated_at": "2026-02-03T16:45:00Z",
      "url": "https://recuerd0.com/workspaces/1/memories/1",
      "obsolete": false,
      "current": true,
      "root_id": 1,
      "workspace": {
        "id": 1,
        "name": "Project Notes",
        "state": "active",
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
  "ignored_words": [],
  "total_results": 2,
  "obsolete_hidden": 0,
  "results": [
    {
      "id": 1,
      "title": "Design Doc",
      "version": 1,
      "version_label": "v1",
      "has_versions": false,
      "tags": ["design"],
      "source": "manual",
      "category": "decision",
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
      "obsolete": false,
      "current": true,
      "root_id": 1,
      "workspace": {
        "id": 1,
        "name": "Project Notes",
        "state": "active",
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
GET /search.json?q=release notes
```

In the last example, `release notes` matches memories containing both words, or
tagged exactly `release notes` — the same result MCP returns. Quote it,
`"release notes"`, for the exact phrase.

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

A query over 100 characters gets the same response, with the message `Query must be at most 100 characters`.

### MCP and workspace search

The MCP `list_memories.query` argument and the search field within a workspace use
the same contract as REST search above. Blank queries return the ordinary unfiltered
listing, and queries of one or two characters skip FTS and search exact tags only,
ordered by recency. MCP search appends related memories the same way REST does;
pass `retrieval: "lexical"` for keyword matches only. The workspace filter is
keyword-only.

Sort defaults are query-aware. With a query, omitted or invalid `sort` defaults
to `relevance`; without a query it defaults to `updated`. Explicit `updated`,
`created`, or `title` always wins. Explicit `relevance` preserves the search
order when a query is present and resolves to `updated` without one.

---

## Common Errors

| Status | Code | Meaning |
|---|---|---|
| 400 | `BAD_REQUEST` | The request body isn't valid JSON |
| 401 | `UNAUTHORIZED` | Missing, invalid or expired token |
| 403 | `FORBIDDEN` | Read-only token, an inactive workspace, changing or deleting something you neither own nor administer, or a link you can't remove |
| 404 | `NOT_FOUND` | No such resource or path |
| 406 | `NOT_ACCEPTABLE` | The endpoint has no JSON representation |
| 422 | `VALIDATION_ERROR` | The request is well formed but its data isn't acceptable |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_SERVER_ERROR` | Something went wrong on the server |

### 400 Bad Request

Returned when the request body can't be parsed as JSON. A body that parses but has the wrong shape (empty, an array, or sent as `text/plain`) is a `422`.

```json
{
  "error": {
    "code": "BAD_REQUEST",
    "message": "The request body is not valid JSON",
    "status": 400
  }
}
```

### 401 Unauthorized

Returned when the token is missing, invalid or expired, and when a valid token
is presented to an endpoint outside the API surface (profile, password, account
or OAuth consent). A presented `Authorization: Bearer` header is authoritative:
it never falls back to a browser session, so a bad token on a signed-in browser
is still a `401`.

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

Returned when using a `read_only` token for write operations. This covers every
request whose method is not GET or HEAD, whatever `Accept` header it carries:

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

Or when a member removes a link they didn't create:

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Only an admin or the person who created this link can remove it.",
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
    "message": "Give your workspace a name so you can find it later.",
    "details": {
      "name": ["Give your workspace a name so you can find it later."]
    },
    "status": 422
  }
}
```

### 429 Too Many Requests

The response carries a `Retry-After: 60` header.

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests",
    "status": 429
  }
}
```
