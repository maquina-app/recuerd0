class SkillsController < ApplicationController
  allow_unauthenticated_access

  def recuerd0_mcp
    send_file Rails.root.join("skills/recuerd0-mcp/SKILL.md"),
      type: "text/markdown; charset=utf-8",
      disposition: "attachment",
      filename: "SKILL.md"
  end
end
