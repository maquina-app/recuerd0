require "test_helper"

class ApiSearchTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @read_only_token = "test_read_token_123"
    @full_access_token = "test_full_token_456"
    @other_user_token = "other_user_token_789"

    [memories(:one), memories(:versioned_parent)].each(&:rebuild_search_index)
  end

  # Authentication
  test "requires authentication" do
    get search_url(format: :json), params: {q: "Meeting"}
    assert_response :unauthorized
  end

  test "works with read_only token" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@read_only_token)

    assert_response :success
  end

  test "works with full_access token" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@full_access_token)

    assert_response :success
  end

  # Validation
  test "returns 422 for missing query parameter" do
    get search_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
    assert_equal "Query parameter is required", json["error"]["message"]
  end

  test "returns 422 for empty query" do
    get search_url(format: :json),
      params: {q: ""},
      headers: auth_headers(@read_only_token)

    assert_response :unprocessable_entity
  end

  test "returns 422 for query shorter than 3 characters" do
    get search_url(format: :json),
      params: {q: "ab"},
      headers: auth_headers(@read_only_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
    assert_match(/at least 3 characters/, json["error"]["message"])
  end

  # Successful search
  test "returns results for matching query" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Meeting", json["query"]
    assert json["total_results"] >= 1
    assert_kind_of Array, json["results"]
    assert json["results"].length >= 1
  end

  test "returns empty results for no matches" do
    get search_url(format: :json),
      params: {q: "xyznonexistent"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["total_results"]
    assert_equal [], json["results"]
  end

  test "result includes expected fields" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    result = json["results"].first

    assert result.key?("id")
    assert result.key?("title")
    assert result.key?("version")
    assert result.key?("tags")
    assert result.key?("snippet")
    assert result.key?("workspace")
    assert result["workspace"].key?("id")
    assert result["workspace"].key?("name")
  end

  test "result includes snippet" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@read_only_token)

    json = JSON.parse(response.body)
    result = json["results"].first
    assert result["snippet"].present?
    # Snippet should be plain text (no markdown)
    refute_match(/#/, result["snippet"])
  end

  # Pagination
  test "includes pagination headers" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    assert response.headers["X-Page"].present?
    assert response.headers["X-Total"].present?
    assert response.headers["X-Total-Pages"].present?
  end

  test "pagination link header preserves query parameter" do
    get search_url(format: :json),
      params: {q: "Meeting"},
      headers: auth_headers(@read_only_token)

    link_header = response.headers["Link"]
    assert link_header.present?
    assert_match(/q=Meeting/, link_header)
  end

  # Account isolation
  test "cannot see other accounts memories" do
    memories(:two).rebuild_search_index

    get search_url(format: :json),
      params: {q: "Shopping"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json["total_results"]
  end

  # Workspace filter
  test "filters by workspace_id" do
    workspace = workspaces(:one)

    get search_url(format: :json),
      params: {q: "Meeting", workspace_id: workspace.id},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    json["results"].each do |result|
      assert_equal workspace.id, result["workspace"]["id"]
    end
  end

  test "returns 404 for invalid workspace_id" do
    get search_url(format: :json),
      params: {q: "Meeting", workspace_id: 999999},
      headers: auth_headers(@read_only_token)

    assert_response :not_found
  end

  # FTS5 operators
  test "supports AND operator" do
    get search_url(format: :json),
      params: {q: "Meeting AND project"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json["results"]
  end

  test "supports OR operator" do
    get search_url(format: :json),
      params: {q: "Meeting OR Design"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["total_results"] >= 1
  end

  test "supports NOT operator" do
    get search_url(format: :json),
      params: {q: "Meeting NOT Shopping"},
      headers: auth_headers(@read_only_token)

    assert_response :success
  end

  test "supports phrase search" do
    get search_url(format: :json),
      params: {q: '"Meeting Notes"'},
      headers: auth_headers(@read_only_token)

    assert_response :success
  end

  test "supports column filter" do
    get search_url(format: :json),
      params: {q: "title:Meeting"},
      headers: auth_headers(@read_only_token)

    assert_response :success
  end

  test "returns 422 for invalid FTS5 syntax" do
    get search_url(format: :json),
      params: {q: "AND OR NOT"},
      headers: auth_headers(@read_only_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
    assert_match(/Invalid search query syntax/, json["error"]["message"])
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
