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

  test "every figure excludes obsolete memories unless include=obsolete" do
    current = Memory.create_with_content(@workspace, title: "Current", content: "b", category: "decision", tags: ["alpha"])
    obsolete = Memory.create_with_content(@workspace, title: "Retired", content: "b", category: "decision", tags: ["obsolete", "beta"])
    obsolete.create_version!(title: "Retired", content: "b2", tags: ["obsolete", "beta"], category: "decision")
    other_obsolete = Memory.create_with_content(@workspace, title: "Also retired", content: "b", tags: ["obsolete"])
    # Both ends hidden, so the link disappears with them. A link that still
    # touches a visible memory keeps counting.
    MemoryLink.create!(from_memory_id: obsolete.id, to_memory_id: other_obsolete.id)

    get workspace_stats_url(@workspace, format: :json), headers: auth_headers(@read_only_token)
    assert_response :success
    filtered = JSON.parse(response.body)

    get workspace_stats_url(@workspace, format: :json), params: {include: "obsolete"},
      headers: auth_headers(@read_only_token)
    assert_response :success
    unfiltered = JSON.parse(response.body)

    assert_equal filtered["total_memories"] + 2, unfiltered["total_memories"]
    assert_equal filtered["counts_by_category"]["decision"] + 1, unfiltered["counts_by_category"]["decision"]
    # Two obsolete roots plus one version row.
    assert_equal filtered["total_versions"] + 3, unfiltered["total_versions"]
    assert_equal 0, filtered["total_links"]
    assert_equal 1, unfiltered["total_links"]
    refute filtered["top_tags"].any? { |t| ["obsolete", "beta"].include?(t["tag"]) }
    assert unfiltered["top_tags"].any? { |t| t["tag"] == "obsolete" }
    assert_equal filtered["memories_by_week"].values.sum + 2, unfiltered["memories_by_week"].values.sum
    assert current.reload.persisted?
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
