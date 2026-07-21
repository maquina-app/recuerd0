require "test_helper"

class Workspaces::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @workspace = @account.workspaces.create!(
      name: "Exportable",
      description: "Everything in one JSON document"
    )
    @read_only_token = "test_read_token_123"
  end

  test "exports workspace metadata and defaults to JSON" do
    get workspace_export_url(@workspace), headers: auth_headers(@read_only_token)

    assert_response :success
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert_equal "recuerd0.workspace_export", json["format"]
    assert_equal 1, json["format_version"]
    assert Time.iso8601(json["exported_at"])
    assert_equal({
      "id" => @workspace.id,
      "name" => @workspace.name,
      "description" => @workspace.description,
      "memories_count" => @workspace.memories_count,
      "archived" => false,
      "created_at" => @workspace.created_at.utc.iso8601(3),
      "updated_at" => @workspace.updated_at.utc.iso8601(3)
    }, json["workspace"])
  end

  test "exports one entry per root with complete ordered raw Markdown history" do
    v1_body = "# Version 1\n\nLiteral <em>Markdown</em> & text.\n"
    v2_body = "## Version 2\n\n- alpha\n- beta\n"
    v3_body = "```ruby\nputs \"v3\"\n```\n"
    root = Memory.create_with_content(@workspace, title: "First", content: v1_body)
    root.create_version!(title: "Second", content: v2_body)
    root.create_version!(title: "Third", content: v3_body)
    other = Memory.create_with_content(@workspace, title: "Other", content: "Only version\n")

    get workspace_export_url(@workspace), headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [root.id, other.id].sort, json["memories"].map { |memory| memory["id"] }

    exported = json["memories"].find { |memory| memory["id"] == root.id }
    assert_equal v1_body, exported["content"]
    assert_equal [1, 2, 3], exported["versions"].map { |version| version["version"] }
    assert_equal [v1_body, v2_body, v3_body], exported["versions"].map { |version| version["content"] }
    assert_equal v3_body, exported["versions"].last["content"]

    metadata_keys = %w[id title tags source category version version_label has_versions links_count created_at updated_at url workspace]
    assert_equal metadata_keys.sort, (exported.keys - %w[content versions]).sort
    assert_equal metadata_keys.sort, (exported["versions"].last.keys - ["content"]).sort
  end

  test "allows a read-only token" do
    get workspace_export_url(@workspace), headers: auth_headers(@read_only_token)

    assert_response :success
  end

  test "allows an authenticated session" do
    sign_in_as(users(:one))

    get workspace_export_url(@workspace)

    assert_response :success
  end

  test "requires authentication" do
    get workspace_export_url(@workspace)

    assert_response :unauthorized
  end

  test "does not expose a workspace from another account" do
    get workspace_export_url(@workspace), headers: auth_headers("other_user_token_789")

    assert_response :not_found
  end

  test "sets inline disposition and disables caching" do
    get workspace_export_url(@workspace), headers: auth_headers(@read_only_token)

    assert_response :success
    assert_equal "inline", response.headers["Content-Disposition"]
    assert_includes response.headers["Cache-Control"], "no-cache"
  end

  test "exports archived and deleted workspaces" do
    get workspace_export_url(workspaces(:archived)), headers: auth_headers(@read_only_token)
    assert_response :success
    assert JSON.parse(response.body).dig("workspace", "archived")

    get workspace_export_url(workspaces(:deleted)), headers: auth_headers(@read_only_token)
    assert_response :success
  end

  test "uses a constant number of queries for all memories and versions" do
    3.times do |root_index|
      root = Memory.create_with_content(@workspace,
        title: "Root #{root_index}", content: "v1 body #{root_index}")
      root.create_version!(content: "v2 body #{root_index}")
      root.create_version!(content: "v3 body #{root_index}")
    end

    assert_queries_count 13 do
      get workspace_export_url(@workspace), headers: auth_headers(@read_only_token)
    end
    assert_response :success
  end
end
