require "test_helper"

class SkillsControllerTest < ActionDispatch::IntegrationTest
  test "GET recuerd0 MCP skill publicly downloads the verbatim Markdown file" do
    expected = Rails.root.join("skills/recuerd0-mcp/SKILL.md").binread

    get recuerd0_mcp_skill_url

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_equal "text/markdown; charset=utf-8", response.headers["Content-Type"]
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/filename="SKILL\.md"/, response.headers["Content-Disposition"])
    assert_predicate response.body, :present?
    assert_equal expected.bytes, response.body.bytes
    markdown = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes MarkdownRenderer.build.render(markdown), "<h1"
  end
end
