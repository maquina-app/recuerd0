require "test_helper"

class ApiAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @read_only_token = "test_read_token_123"
    @full_access_token = "test_full_token_456"
  end

  test "api auth with valid read_only token" do
    get workspaces_url(format: :json),
      headers: {"Authorization" => "Bearer #{@read_only_token}"}

    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "api auth with valid full_access token" do
    get workspaces_url(format: :json),
      headers: {"Authorization" => "Bearer #{@full_access_token}"}

    assert_response :success
  end

  test "api auth with invalid token returns 401" do
    get workspaces_url(format: :json),
      headers: {"Authorization" => "Bearer invalid_token"}

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "UNAUTHORIZED", json["error"]["code"]
  end

  test "api auth without token returns 401" do
    get workspaces_url(format: :json)

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "UNAUTHORIZED", json["error"]["code"]
  end

  test "api auth with malformed authorization header returns 401" do
    get workspaces_url(format: :json),
      headers: {"Authorization" => "Basic sometoken"}

    assert_response :unauthorized
  end

  test "read_only token can access GET endpoints" do
    workspace = workspaces(:one)

    get workspace_url(workspace, format: :json),
      headers: {"Authorization" => "Bearer #{@read_only_token}"}

    assert_response :success
  end

  test "read_only token cannot access POST endpoints" do
    post workspaces_url(format: :json),
      params: {workspace: {name: "New Workspace"}},
      headers: {"Authorization" => "Bearer #{@read_only_token}"}

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal "FORBIDDEN", json["error"]["code"]
  end

  test "full_access token can access POST endpoints" do
    post workspaces_url(format: :json),
      params: {workspace: {name: "New Workspace"}},
      headers: {"Authorization" => "Bearer #{@full_access_token}"}

    assert_response :created
  end

  test "token last_used_at is updated on API request" do
    token = access_tokens(:read_only_token)
    assert_nil token.last_used_at

    get workspaces_url(format: :json),
      headers: {"Authorization" => "Bearer #{@read_only_token}"}

    token.reload
    assert token.last_used_at.present?
  end

  test "api auth respects account scope" do
    other_user_token = "other_user_token_789"
    workspace = workspaces(:one)

    get workspace_url(workspace, format: :json),
      headers: {"Authorization" => "Bearer #{other_user_token}"}

    assert_response :not_found
  end

  test "session auth still works for JSON requests" do
    sign_in_as(@user)

    get workspaces_url(format: :json)

    assert_response :success
  end
end
