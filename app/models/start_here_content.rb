module StartHereContent
  MEMORIES = [
    {
      title: "_MAP",
      tags: ["getting-started", "map"],
      pinned: true,
      content: <<~MARKDOWN
        # _MAP

        ## Start here

        1. **Create a personal access token** — in the web app, open **Access Tokens**, choose **Full access**, and copy it when it appears.
        2. **Install and connect the CLI** — one account command makes every CLI workflow available.
        3. **Import what you already know** — propose a plan, review it, then commit it.
        4. **Connect your AI tools** — install the skill, use the Claude Code plugin, or connect over MCP.

        Full walkthrough: https://recuerd0.ai/start

        ## Your workspace

        - **Continuation Brief** — where things stand and what's next. Read second.
        - **_INDEX — Decisions** — one line per decision you lock.

        ## Why this shape

        Every session — yours or your AI tool's — starts cold. The map is the front door: one read orients the session and keeps every memory reachable within two hops. The brief carries state between sessions, versioned so history becomes the log. The index keeps locked decisions one line — and one hop — away. Keep the map flat until ~20 memories; past that, group clusters behind hub memories. Write every line in the words you'd ask with — "where do the images live", not only "storage architecture" — so cold sessions can route themselves.
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
