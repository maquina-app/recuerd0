require "test_helper"

class MemoriesControllerPreviewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)

    post session_url, params: {email_address: @user.email_address, password: "password"}
  end

  test "preview renders markdown content in turbo frame" do
    post preview_workspace_memories_url(@workspace), params: {content: "# Hello\n\n**Bold text**"}

    assert_response :success
    assert_match "markdown_preview", response.body
    assert_match "<h1>", response.body
    assert_match "<strong>Bold text</strong>", response.body
  end

  test "preview renders empty state for blank content" do
    post preview_workspace_memories_url(@workspace), params: {content: ""}

    assert_response :success
    assert_match "markdown_preview", response.body
    assert_match "Nothing to preview", response.body
  end

  test "preview renders empty state when content param is missing" do
    post preview_workspace_memories_url(@workspace)

    assert_response :success
    assert_match "Nothing to preview", response.body
  end

  test "preview renders without layout" do
    post preview_workspace_memories_url(@workspace), params: {content: "# Test"}

    assert_response :success
    assert_no_match "<html", response.body
  end
end
