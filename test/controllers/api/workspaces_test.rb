require "test_helper"

class ApiWorkspacesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @full_access_token = "test_full_token_456"
    @read_only_token = "test_read_token_123"
  end

  # Index tests
  test "index returns workspaces json" do
    get workspaces_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert json.any? { |w| w["name"] == "Project Notes" }
  end

  test "index includes pagination headers" do
    get workspaces_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    assert response.headers["X-Page"].present?
    assert response.headers["X-Total"].present?
    assert response.headers["X-Total-Pages"].present?
    assert response.headers["Link"].present?
  end

  test "index only returns active workspaces" do
    get workspaces_url(format: :json),
      headers: auth_headers(@read_only_token)

    json = JSON.parse(response.body)
    names = json.map { |w| w["name"] }

    assert_includes names, "Project Notes"
    assert_not_includes names, "Old Project"  # archived
    assert_not_includes names, "Deleted Project"  # deleted
  end

  # Show tests
  test "show returns workspace json" do
    get workspace_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Project Notes", json["name"]
    assert_equal @workspace.id, json["id"]
    assert json.key?("memories_count")
    assert json.key?("url")
  end

  test "show returns 404 for non-existent workspace" do
    get workspace_url(id: 999999, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "NOT_FOUND", json["error"]["code"]
  end

  # Create tests
  test "create workspace via api" do
    assert_difference "Workspace.count", 1 do
      post workspaces_url(format: :json),
        params: {workspace: {name: "API Workspace", description: "Created via API"}},
        headers: auth_headers(@full_access_token)
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "API Workspace", json["name"]
  end

  test "create workspace requires full_access token" do
    assert_no_difference "Workspace.count" do
      post workspaces_url(format: :json),
        params: {workspace: {name: "Should Fail"}},
        headers: auth_headers(@read_only_token)
    end

    assert_response :forbidden
  end

  test "create workspace returns validation errors" do
    post workspaces_url(format: :json),
      params: {workspace: {name: ""}},
      headers: auth_headers(@full_access_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
  end

  # Update tests
  test "update workspace via api" do
    patch workspace_url(@workspace, format: :json),
      params: {workspace: {name: "Updated Name"}},
      headers: auth_headers(@full_access_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Name", json["name"]
    assert_equal "Updated Name", @workspace.reload.name
  end

  test "update workspace requires full_access token" do
    patch workspace_url(@workspace, format: :json),
      params: {workspace: {name: "Should Not Update"}},
      headers: auth_headers(@read_only_token)

    assert_response :forbidden
    assert_not_equal "Should Not Update", @workspace.reload.name
  end

  # Destroy tests
  test "destroy workspace via api" do
    delete workspace_url(@workspace, format: :json),
      headers: auth_headers(@full_access_token)

    assert_response :no_content
    assert @workspace.reload.deleted?
  end

  test "destroy workspace requires full_access token" do
    delete workspace_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :forbidden
    assert_not @workspace.reload.deleted?
  end

  # Account scoping tests
  test "api respects account scope" do
    other_workspace = workspaces(:two)  # belongs to account two

    get workspace_url(other_workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
