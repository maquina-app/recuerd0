module StartHereContent
  MEMORIES = [
    {
      title: "_MAP",
      tags: ["getting-started", "map"],
      pinned: true,
      content: <<~MARKDOWN
        # _MAP

        Read this first, every session — you or your AI tool. One line per entry, written the way you'd actually ask for it.

        ## Start here

        1. **Create an access token** — Access Tokens in the sidebar. Pick full access if your tools will write.
        2. **Install the CLI and connect** — `brew install maquina-app/tap/recuerd0`, then `recuerd0 account add`.
        3. **Import what you already have** — `recuerd0 import propose <path>`, review the plan it writes, then `recuerd0 import commit`.
        4. **Give your agent the skill** — `recuerd0 skills install`, or the Claude Code plugin.

        The full walkthrough, including connecting over MCP: __BASE_URL__/start

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

        - Import existing notes — step 3 on the map.
        - Give your agent the skill — step 4 on the map.

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
