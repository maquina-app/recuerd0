require "test_helper"

class Memories::VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:versioned_parent)
    sign_in_as(@user)
  end

  test "index lists versions" do
    get workspace_memory_versions_url(@workspace, @memory)
    assert_response :success
  end

  test "create makes new version" do
    assert_difference("Memory.count") do
      post workspace_memory_versions_url(@workspace, @memory)
    end
  end

  test "create version via json with custom title and content" do
    assert_difference("Memory.count") do
      post workspace_memory_versions_url(@workspace, @memory, format: :json),
        params: {version: {title: "Updated Title", content: "Updated body text"}},
        headers: auth_headers("test_full_token_456")
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Updated Title", json["title"]
    assert_equal "Updated body text", json["content"]["body"]
    assert_equal 2, json["version"]
  end
end
