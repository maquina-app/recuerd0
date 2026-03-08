require "test_helper"

class Memories::MarkdownsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    sign_in_as(@user)
  end

  test "show serves raw markdown content" do
    get workspace_memory_markdown_url(@workspace, @memory)
    assert_response :success
    assert_includes response.content_type, "text/markdown"
    assert_equal @memory.content.body, response.body
    assert_includes response.headers["Content-Disposition"], "inline"
    assert_includes response.headers["Content-Disposition"], ".md"
  end

  test "show resolves to current version for root memory with versions" do
    parent = memories(:versioned_parent)
    parent.create_version!(title: "Latest Version", content: "Latest content")

    get workspace_memory_markdown_url(parent.workspace, parent)
    assert_response :success
    assert_includes response.content_type, "text/markdown"
    assert_equal "Latest content", response.body
  end

  test "show handles memory without content" do
    @memory.content&.destroy
    @memory.reload

    get workspace_memory_markdown_url(@workspace, @memory)
    assert_response :success
    assert_includes response.content_type, "text/markdown"
    assert_equal "", response.body
  end

  test "show requires authentication" do
    reset!

    get workspace_memory_markdown_url(@workspace, @memory)
    assert_redirected_to new_session_url
  end
end
