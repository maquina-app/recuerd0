# recuerd0 over MCP

Use these rules when working with a recuerd0 workspace through the MCP tools.

## Start of session

Call `workspace_context` on the workspace before searching or writing. It returns the workspace's orienting memories, including its map. Read the map before you add anything.

## Conventions

A workspace's conventions are usually recorded in a memory whose title begins with "Map". Follow them. If a workspace has no conventions recorded, do not impose any.

## Writing

- Before creating a memory, check whether one already covers the same ground. If a note supersedes an existing memory, use `create_version` on that memory rather than creating a second one.
- Use `update_memory` to correct a memory, `create_version` when the earlier text should stay readable.
- Titles are what search ranks first.
- Use `link_memories` for memories that belong together.

## Searching

Search matches substrings. One distinctive token or an exact phrase works; boolean operators do not. On a miss, try a different token rather than a broader query.
