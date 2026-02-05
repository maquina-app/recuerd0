require "test_helper"

class ApiArchivesTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @archived_workspace = workspaces(:archived)
    @full_access_token = "test_full_token_456"
    @read_only_token = "test_read_token_123"
  end

  test "archive workspace via api" do
    assert_not @workspace.archived?

    post archive_workspace_url(@workspace, format: :json),
      headers: auth_headers(@full_access_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["archived"]
    assert @workspace.reload.archived?
  end

  test "archive workspace requires full_access token" do
    post archive_workspace_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :forbidden
    assert_not @workspace.reload.archived?
  end

  test "unarchive workspace via api" do
    assert @archived_workspace.archived?

    delete archive_workspace_url(@archived_workspace, format: :json),
      headers: auth_headers(@full_access_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_not json["archived"]
    assert_not @archived_workspace.reload.archived?
  end

  test "unarchive workspace requires full_access token" do
    delete archive_workspace_url(@archived_workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :forbidden
    assert @archived_workspace.reload.archived?
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
