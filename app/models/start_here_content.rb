module StartHereContent
  MEMORIES = [
    {
      title: "_MAP",
      tags: ["getting-started", "map"],
      pinned: true,
      content: <<~MARKDOWN
        # _MAP

        Read this first, every session — you or your AI tool. One line per entry, written the way you'd actually ask for it.

        ## How this workspace is kept

        - Read this map before adding anything, so you know what is already here.
        - Every memory gets one line in the table below, with a short note on what it covers.
        - Before creating a memory, check whether one already covers the same ground. Update or version that one instead of adding a duplicate.
        - Titles state what the memory answers, not the topic it is about.
        - Link memories that belong together.

        These are this workspace's conventions, not the product's. Edit them to match how your team works, or delete this memory if you would rather not work this way.

        The full walkthrough — CLI, import, skills, MCP: __BASE_URL__/start

        ## Your workspace

        - **Continuation Brief** — where things stand and what's next. Read it second; rewrite it as a new version when a session ends.
        - **_INDEX — Decisions** — one line per decision you lock.

        ## Why this shape

        The map is the front door: one read orients a cold session, and every memory stays reachable within two hops. The brief carries state between sessions — its version history becomes your log. The index keeps locked decisions one hop away. Keep the map flat until around twenty memories; past that, group clusters behind hub memories. Search is keyword search, fast and literal, so write map lines and titles the way you'd ask for them. None of this is required — delete anything; a blank workspace is a fine workspace. Full reasoning: __BASE_URL__/start or docs/blueprint.md in the repository.
      MARKDOWN
    },
    {
      title: "Continuation Brief",
      tags: ["getting-started", "continuation"],
      pinned: true,
      content: <<~MARKDOWN
        # Continuation Brief

        The first thing a new session reads after the map. Keep it short; rewrite it at the end of each working session, and save it as a new version — the version history becomes your session log.

        ## State

        Fresh workspace. The starter shape is in place: the map, this brief, the decisions index, and the first decision (D001).

        ## Open

        - Import existing notes — the walkthrough covers it: __BASE_URL__/start
        - Give your agent the skill — `recuerd0 skills install`

        ## Next session

        Read the map, then pick up the first open item above.
      MARKDOWN
    },
    {
      title: "_INDEX — Decisions",
      tags: ["getting-started", "index"],
      pinned: false,
      content: <<~MARKDOWN
        # _INDEX — Decisions

        One line per locked decision, so any of them is two hops from the map. Number them D001, D002, … and give each its own memory: what you chose, why, and what you rejected. Decisions don't get edited later — a changed mind is a new decision that points back.

        | ID | Title |
        |---|---|
        | D001 | Keep this workspace flat until ~20 memories |
      MARKDOWN
    },
    {
      title: "D001 — Keep this workspace flat until ~20 memories",
      tags: ["getting-started", "d001"],
      category: "decision",
      pinned: false,
      content: <<~MARKDOWN
        # D001 — Keep this workspace flat until ~20 memories

        **Chose:** No hubs yet. Every memory gets its own line on the map, written the way you'd ask for it.

        **Why:** A map you can read in one pass beats structure you have to navigate. Hubs earn their place when the map gets crowded — around twenty memories — not before.

        **Rejected:** Seeding an example hub. A hub that routes to nothing breaks the rule that every line points at a real memory; a hub that routes to filler is volume for its own sake.

        **What this defers, illustrated.** Today the map is flat:

        - Payments retry logic — #12
        - Payments webhook quirks — #15
        - Payments provider limits — #18

        Past ~20 memories, those lines collapse into one:

        - Payments — routing in Hub — Payments (#22)

        And the hub is just a routing table — one line of judgment per entry:

        - Why retries drop large jobs — #12
        - Which webhook events lie — #15
        - Provider limits that bit us — #18

        When a real cluster forms here, promote it the same way: create the hub, move the lines, leave one line on the map. A changed mind about this decision is a new decision — D002 — that points back here.
      MARKDOWN
    }
  ].freeze
end
