require "test_helper"

class HttpCacheableTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
  end

  test "memory show returns ETag header" do
    sign_in_as(@user)
    get workspace_memory_url(@workspace, @memory)

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "memory show returns 304 when content unchanged" do
    sign_in_as(@user)
    get workspace_memory_url(@workspace, @memory)
    etag = response.headers["ETag"]

    get workspace_memory_url(@workspace, @memory),
      headers: {"HTTP_IF_NONE_MATCH" => etag}

    assert_response :not_modified
  end

  test "memory show returns 200 when content changed" do
    sign_in_as(@user)
    get workspace_memory_url(@workspace, @memory)
    etag = response.headers["ETag"]

    @memory.content.update!(body: "Changed content")

    get workspace_memory_url(@workspace, @memory),
      headers: {"HTTP_IF_NONE_MATCH" => etag}

    assert_response :success
    assert_not_equal etag, response.headers["ETag"]
  end

  test "cache-control is private for authenticated content" do
    sign_in_as(@user)
    get workspace_memory_url(@workspace, @memory)

    assert_includes response.headers["Cache-Control"], "private"
    assert_not_includes response.headers["Cache-Control"], "public"
  end

  test "workspaces index returns ETag header" do
    sign_in_as(@user)
    get workspaces_url

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "workspaces index returns 304 when unchanged" do
    sign_in_as(@user)
    get workspaces_url
    etag = response.headers["ETag"]

    get workspaces_url, headers: {"HTTP_IF_NONE_MATCH" => etag}

    assert_response :not_modified
  end

  test "workspace show returns ETag header" do
    sign_in_as(@user)
    get workspace_url(@workspace)

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "workspace show returns 304 when unchanged" do
    sign_in_as(@user)
    get workspace_url(@workspace)
    etag = response.headers["ETag"]

    get workspace_url(@workspace), headers: {"HTTP_IF_NONE_MATCH" => etag}

    assert_response :not_modified
  end

  test "versions index returns ETag header" do
    sign_in_as(@user)
    get workspace_memory_versions_url(@workspace, @memory)

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "pinned memories index returns ETag header" do
    sign_in_as(@user)
    get pinned_memories_url

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "archived workspaces index returns ETag header" do
    sign_in_as(@user)
    get archived_workspaces_url

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "deleted workspaces index returns ETag header" do
    sign_in_as(@user)
    get deleted_workspaces_url

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end
end
