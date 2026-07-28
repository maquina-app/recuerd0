require "test_helper"

class SkillsControllerTest < ActionDispatch::IntegrationTest
  test "GET recuerd0 MCP skill publicly downloads the interface and conventions as one Markdown file" do
    get recuerd0_mcp_skill_url

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_equal "text/markdown; charset=utf-8", response.headers["Content-Type"]
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/filename="SKILL\.md"/, response.headers["Content-Disposition"])
    assert_predicate response.body, :present?
    markdown = response.body.dup.force_encoding(Encoding::UTF_8)
    assert_includes markdown, "| load the workspace context | `workspace_context` |"
    assert_includes markdown, "# Workspace conventions"
    assert_includes markdown, "## Boot"
    assert_includes markdown, "## Session lifecycle and capture discipline"
    assert_equal 1, markdown.scan("# Workspace conventions").size
    assert_includes MarkdownRenderer.build.render(markdown), "<h1"
  end
end
