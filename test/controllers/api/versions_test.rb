require "test_helper"

class ApiVersionsTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @full_access_token = "test_full_token_456"
    @read_only_token = "test_read_token_123"
  end

  test "create version via api" do
    assert_difference "Memory.count", 1 do
      post workspace_memory_versions_url(@workspace, @memory, format: :json),
        params: {memory: {content: "New version content"}},
        headers: auth_headers(@full_access_token)
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json["version"]
    assert_equal "New version content", json["content"]["body"]
  end

  test "create version requires full_access token" do
    assert_no_difference "Memory.count" do
      post workspace_memory_versions_url(@workspace, @memory, format: :json),
        params: {memory: {content: "Should fail"}},
        headers: auth_headers(@read_only_token)
    end

    assert_response :forbidden
  end

  test "version copies source attributes" do
    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {memory: {}},
      headers: auth_headers(@full_access_token)

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal @memory.title, json["title"]
    assert_equal @memory.source, json["source"]
  end

  test "version includes custom content" do
    custom_title = "Custom Version Title"
    custom_content = "Custom version body"

    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {memory: {title: custom_title, content: custom_content, tags: ["new"]}},
      headers: auth_headers(@full_access_token)

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal custom_title, json["title"]
    assert_equal custom_content, json["content"]["body"]
    assert_includes json["tags"], "new"
  end

  test "create version with flat json params" do
    assert_difference "Memory.count", 1 do
      post workspace_memory_versions_url(@workspace, @memory, format: :json),
        params: {content: "Flat param content", title: "Flat title"},
        headers: auth_headers(@full_access_token),
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Flat title", json["title"]
    assert_equal "Flat param content", json["content"]["body"]
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
