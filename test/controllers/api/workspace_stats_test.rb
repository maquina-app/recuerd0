require "test_helper"

class ApiWorkspaceStatsTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @read_only_token = "test_read_token_123"
  end

  test "returns aggregate rollup for a workspace" do
    Memory.create_with_content(@workspace, title: "S1", content: "b", category: "decision", tags: ["alpha"])
    Memory.create_with_content(@workspace, title: "S2", content: "b", category: "decision")

    get workspace_stats_url(@workspace, format: :json), headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal Memory::CATEGORIES.sort, json["counts_by_category"].keys.sort
    assert_operator json["counts_by_category"]["decision"], :>=, 2
    assert_operator json["total_memories"], :>=, 2
    assert json["top_tags"].any? { |t| t["tag"] == "alpha" }
  end

  test "requires authentication" do
    get workspace_stats_url(@workspace, format: :json)
    assert_response :unauthorized
  end

  test "does not expose another account's workspace" do
    get workspace_stats_url(workspaces(:two), format: :json), headers: auth_headers(@read_only_token)
    assert_response :not_found
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
