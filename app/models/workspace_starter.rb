module WorkspaceStarter
  TITLE = "Map — how this workspace is kept"
  TAGS = ["getting-started", "map"].freeze
  BODY = <<~MARKDOWN.freeze
    # Map — how this workspace is kept

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

    ## Why this shape

    The map is the front door: one read orients a cold session, and every memory stays reachable within two hops. Index — decisions keeps locked decisions one hop away. Keep the map flat until around twenty memories; past that, group clusters behind hub memories. None of this is required — delete anything; a blank workspace is a fine workspace. Full reasoning: __BASE_URL__/start or docs/blueprint.md in the repository.
  MARKDOWN

  def self.attributes(base_url:, routing_bullets: [])
    {
      title: TITLE,
      tags: TAGS,
      content: content(base_url: base_url, routing_bullets: routing_bullets)
    }
  end

  def self.content(base_url:, routing_bullets: [])
    body = if routing_bullets.any?
      BODY.sub(
        "## Your workspace\n\n",
        "## Your workspace\n\n#{routing_bullets.join("\n")}\n\n"
      )
    else
      BODY
    end

    body.gsub("__BASE_URL__", base_url)
  end
end
