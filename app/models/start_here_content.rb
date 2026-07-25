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

        The full walkthrough, including connecting over MCP: https://recuerd0.ai/start

        ## Your workspace

        - **Continuation Brief** — where things stand and what's next. Read it second; rewrite it as a new version when a session ends.
        - **_INDEX — Decisions** — one line per decision you lock.

        ## Why this shape

        The map is the front door: one read orients a cold session, and every memory stays reachable within two hops. The brief carries state between sessions — its version history becomes your log. The index keeps locked decisions one hop away. Keep the map flat until around twenty memories; past that, group clusters behind hub memories. Search is keyword search, fast and literal, so write map lines and titles the way you'd ask for them. None of this is required — delete anything; a blank workspace is a fine workspace. Full reasoning: https://recuerd0.ai/start or docs/blueprint.md in the repository.
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

        Where the work stands right now. Two or three sentences.

        ## Open

        Questions or threads you deliberately left unresolved.

        ## Next session

        The first thing to pick up next time.
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
        |  |  |
      MARKDOWN
    }
  ].freeze
end
