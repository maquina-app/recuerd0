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

  test "requires authentication" do
    get workspace_merge_candidates_url(@workspace, format: :json)
    assert_response :unauthorized
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
