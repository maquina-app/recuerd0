# recuerd0 over MCP

Use these rules when working with a recuerd0 workspace through the MCP tools.

**Read `references/conventions.md` before writing anything.** It carries the workspace
conventions — boot order, titling, decisions, map maintenance, hubs, and capture
discipline. A workspace's own recorded conventions take precedence over both files.

## Operations

| Operation | Tool |
|---|---|
| load the workspace context | `workspace_context` |
| search | `list_memories` with a query |
| read a memory | `read_memory`, or `read_memories` for several at once |
| create a memory | `create_memory` |
| create a version | `create_version` |
| update a memory | `update_memory` |
| link memories | `link_memories` |

`read_memories` accepts an array — batch reads rather than fetching one at a time.

## Surface notes

Importing a folder of files is not available over MCP; it reads files from the machine and
requires the CLI.

Memory links connect memories across workspaces within the same account. Within a single
workspace, use the map's routing lines instead. Links are undirected, unlabeled, and
same-account only.

Search matches substrings, and every word has to match. One distinctive token or an exact
phrase works best. Uppercase `AND`, `OR` and `NOT` work too. Words under 3 characters are
left out and listed in `ignored_words`. Results marked `match: "related"` are close in
meaning but don't contain the words. On a miss, try a different token rather than a
broader query.
