require "test_helper"

class ApiMergeCandidatesTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @read_only_token = "test_read_token_123"
  end

  test "returns clustered merge candidates" do
    Memory.create_with_content(@workspace, title: "Incident postmortem", content: "b", tags: ["sre"])
    Memory.create_with_content(@workspace, title: "Incident postmortem", content: "b", tags: ["sre"])

    get workspace_merge_candidates_url(@workspace, format: :json), headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    cluster = json["candidates"].find { |c| c["memories"].any? { |m| m["title"] == "Incident postmortem" } }
    assert cluster, "expected a cluster containing the duplicate memories"
    assert_operator cluster["score"], :>=, 0.5
    assert_equal 2, cluster["memories"].size
  end

  test "cluster memories state obsolete, current and root_id" do
    root = Memory.create_with_content(@workspace, title: "Incident postmortem", content: "b", tags: ["sre"])
    root.create_version!(content: "b2")
    Memory.create_with_content(@workspace, title: "Incident postmortem", content: "b", tags: ["sre"])

    get workspace_merge_candidates_url(@workspace, format: :json), headers: auth_headers(@read_only_token)

    assert_response :success
    cluster = JSON.parse(response.body)["candidates"]
      .find { |c| c["memories"].any? { |m| m["title"] == "Incident postmortem" } }
    payload = cluster["memories"].find { |m| m["id"] == root.id }
    assert_equal false, payload["obsolete"]
    assert_equal true, payload["current"]
    assert_equal root.id, payload["root_id"]
  end

  test "requires authentication" do
    get workspace_merge_candidates_url(@workspace, format: :json)
    assert_response :unauthorized
  end

  test "an obsolete near-duplicate only clusters with include=obsolete" do
    Memory.create_with_content(@workspace, title: "Retry policy", content: "b", tags: ["sre"])
    Memory.create_with_content(@workspace, title: "Retry policy", content: "b", tags: ["sre", "Superseded"])

    get workspace_merge_candidates_url(@workspace, format: :json), headers: auth_headers(@read_only_token)
    assert_response :success
    refute JSON.parse(response.body)["candidates"].any? { |c| c["memories"].any? { |m| m["title"] == "Retry policy" } }

    get workspace_merge_candidates_url(@workspace, format: :json), params: {include: "obsolete"},
      headers: auth_headers(@read_only_token)
    assert_response :success
    cluster = JSON.parse(response.body)["candidates"].find { |c| c["memories"].any? { |m| m["title"] == "Retry policy" } }
    assert cluster, "expected the obsolete near-duplicate to cluster when included"
    assert_equal 2, cluster["memories"].size
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
