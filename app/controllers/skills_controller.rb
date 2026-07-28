class SkillsController < ApplicationController
  allow_unauthenticated_access

  def recuerd0_mcp
    skill = Rails.root.join("skills/recuerd0-mcp/SKILL.md").binread.sub(/\n+\z/, "")
    conventions = Rails.root.join(
      "skills/recuerd0-mcp/references/conventions.md"
    ).binread

    send_data skill + "\n\n" + conventions,
      type: "text/markdown; charset=utf-8",
      disposition: "attachment",
      filename: "SKILL.md"
  end
end
