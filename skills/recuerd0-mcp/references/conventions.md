# Workspace conventions

Every new recuerd0 account starts with **My Workspace**, already shaped around four
memories: Map — how this workspace is kept, Continuation Brief, Index — decisions, and
D001 — the first decision.

Apply the writing, titling, decision, map, hub, import, and governance conventions
whenever working in a recuerd0 workspace.

A workspace's own conventions take precedence over this file. If the workspace records
how it is kept — usually in a memory whose title begins with "Map" — follow that instead
of the rules below. If a workspace records no conventions, do not impose these; treat
them as a default the user has not chosen.

## Boot

At the start of a session, load the workspace context before searching or writing. Then:

1. Read `Map — how this workspace is kept` first and `Continuation Brief` second.
2. Treat the workspace description, map, brief, and other pinned memories as project
   context. Follow current decisions and preferences unless the repository proves they
   are stale.

Do not create a workspace implicitly.

If the workspace has no map, do not create one unprompted. Work from search, and offer to create one once there is enough to route to.

## Searching

Use `Map — how this workspace is kept` as the front door. Follow its routes directly or
through one hub when the question is phrased in the user's own words. The map supplies
the judgment literal keyword search cannot.

Search for exact memory titles, decision numbers, code identifiers, tags, and phrases
likely to occur in the text. Keep queries short and distinctive — one distinctive token
or an exact phrase. Matching is substring-level, so boolean operators and bags of words
do not help. On a miss, try a different token rather than a broader query.

Write map lines, hub lines, and titles in asking-vocabulary: the words someone arriving
cold would actually use. "Where do the images live?" routes better than "storage
architecture."

## Writing

Treat every title as a retrieval surface. Make it concrete, scoped, and recognizable in
search results; avoid vague titles such as "Notes," "Update," or "Architecture."

Reuse a small, stable vocabulary of lowercase tags already established in the workspace.
Choose the narrowest category that fits:

- `decision` for a choice and its rationale;
- `discovery` for a finding, constraint, or bug root cause;
- `preference` for a durable user or team preference;
- `general` only when none of the specific categories fit.

Search before creating. If a memory already covers the topic, create a version instead of
a duplicate. Create a version for substantive title, body, tag, or category changes so
history remains visible. Reserve updating a memory for correcting an accidental write,
not for evolving knowledge.

Create a version of `Continuation Brief` at the end of each substantive session. Its
version history is the session log.

## Decisions

Number locked decisions sequentially as D001, D002, and so on.

Give each decision its own memory titled `D### — <decision>`. Record what was chosen, why,
and what was rejected. Add one corresponding line to `Index — decisions` so every decision
remains two hops from the map.

Do not rewrite a decision when the choice changes. Create the next D-numbered decision,
state which earlier decision it supersedes, and point back to it. Preserve the old
rationale; if the old memory needs a forward pointer, add that marker as a new version
rather than erasing its original state. Keep both entries in the decision index.

Add every new decision to both the index and the map in the same pass. A decision absent
from both is a decision the next session cannot see.

## Map maintenance

Maintain structure in two passes:

1. Create or version the content memories first.
2. After every target exists, create a new map or hub version that routes to them.

Keep every memory reachable within two hops of the map: directly from the map, or from
one hub the map routes to. Never leave a route pointing at a memory that does not exist.

Write one concise line of judgment per route in asking-vocabulary. A line should tell a
cold reader why to follow it, not merely repeat the destination's title. Add, change, or
remove map lines whenever the underlying structure changes.

## Hubs

Keep the map flat until roughly twenty memories. Hubs earn their place only when a real
cluster makes the map crowded.

Promote a cluster in four steps:

1. Identify a coherent cluster already represented by several map lines.
2. Create a `Hub — <topic>` memory with one asking-vocabulary routing line per cluster
   memory.
3. Create a new map version that replaces those cluster lines with one line pointing to
   the hub.
4. Verify that every moved memory is still reachable within two hops and that every route
   points at a real memory.

Do not seed empty hubs or create filler to justify them.

## After an import

Importing a folder of files requires the CLI — it reads files from the machine. A
workspace can still be imported into by its owner's CLI or a teammate's, so this applies
however the import happened.

Do not leave an import as an unstructured pile. After the import completes:

1. Group the imported memories into useful clusters and draft asking-vocabulary map lines
   for them.
2. Identify weak titles that will not retrieve well. Fix each one by creating a version
   with a better title, preserving the imported version.
3. If the workspace is now past roughly twenty memories, propose real cluster promotions
   behind hubs; do not create hubs automatically.
4. Present the title changes, cluster routes, and hub proposals for review.
5. Apply approved content or hub writes first, then apply the reviewed routing structure
   as a new map version.

## Write governance

Read and search freely. Before filing memories or changing the map, a hub, a decision, or
an index, show the proposed write and get human confirmation. Import execution follows its
stricter propose → review → commit protocol and requires explicit approval before
execution.

Never create structural filler, dangling routes, duplicate memories, or silent decision
rewrites. Preserve provenance and history through versions. After writing, verify the
response and report what was created or versioned, including memory IDs.

## Session lifecycle and capture discipline

### During work

- Search to recover relevant decisions, discoveries, and preferences as needed.
- For large memories, read selectively where the interface supports it rather than
  pulling the whole body.
- Treat memories as context, not as a substitute for inspecting the current code and
  tests.
- If a memory conflicts with the repository, call out the mismatch and verify which
  source is current.

### Capturing knowledge

Capture knowledge only after it is confirmed and useful beyond the current session:

- decisions and their rationale;
- non-obvious discoveries or bug root causes;
- durable user or team preferences;
- operational details that cost meaningful time to establish.

Do not save routine implementation details, facts obvious from the code, transient
progress, secrets, credentials, or unverified guesses.

Before creating a memory, search for the topic in the workspace. Create a version of a
strong existing match instead of a duplicate. Update only to correct a memory that was
wrong rather than superseded.

### End of a session

After substantive work, consider whether the session produced durable knowledge that
passes the capture rules above. Save only that distilled knowledge, not a raw transcript,
and report what was created, versioned, or updated.
