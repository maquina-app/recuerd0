require "test_helper"

# Proves the account boundary on every token-reachable endpoint. Every request
# here carries account two's token and account one's ids. Nothing new is
# expected to fail — the point is that a misconfigured workspace id keeps
# failing safely, and keeps failing *indistinguishably* from a missing id, so
# the 404 cannot be used to enumerate another account's records.
class ApiAccountIsolationTest < ActionDispatch::IntegrationTest
  MISSING_ID = 999_999

  setup do
    @token = "other_user_token_789"                # users(:two), account two
    @workspace = workspaces(:one)                  # account one
    @memory = memories(:one)                       # account one
    @own_workspace = workspaces(:two)              # account two
    @own_memory = memories(:two)                   # account two
  end

  # --- Reads -----------------------------------------------------------------

  test "foreign workspace reads are indistinguishable from a missing id" do
    [
      ->(id) { workspace_url(id, format: :json) },
      ->(id) { workspace_context_url(workspace_id: id, format: :json) },
      ->(id) { workspace_stats_url(workspace_id: id, format: :json) },
      ->(id) { workspace_merge_candidates_url(workspace_id: id, format: :json) },
      ->(id) { workspace_export_url(workspace_id: id, format: :json) },
      ->(id) { workspace_memories_url(workspace_id: id, format: :json) }
    ].each do |path|
      get path.call(@workspace.id), headers: auth
      assert_response :not_found, path.call(@workspace.id)
      foreign_body = response.body

      get path.call(MISSING_ID), headers: auth
      assert_response :not_found
      assert_equal response.body, foreign_body, "#{path.call(@workspace.id)} leaks existence"
    end
  end

  test "foreign memory reads answer the standard 404" do
    [
      workspace_memory_url(workspace_id: @workspace.id, id: @memory.id, format: :json),
      workspace_memory_versions_url(workspace_id: @workspace.id, memory_id: @memory.id, format: :json),
      workspace_memory_version_url(workspace_id: @workspace.id, memory_id: @memory.id, id: @memory.id, format: :json),
      workspace_memory_links_url(workspace_id: @workspace.id, memory_id: @memory.id, format: :json)
    ].each do |path|
      get path, headers: auth
      assert_response :not_found, path
      assert_not_found_body
    end
  end

  # --- Writes ----------------------------------------------------------------

  test "foreign workspace writes answer 404 and change nothing" do
    attributes = @workspace.attributes

    patch workspace_url(@workspace, format: :json), params: {workspace: {name: "Hijacked"}}, headers: auth
    assert_response :not_found
    assert_not_found_body

    post archive_workspace_url(@workspace, format: :json), headers: auth
    assert_response :not_found

    delete archive_workspace_url(@workspace, format: :json), headers: auth
    assert_response :not_found

    delete workspace_url(@workspace, format: :json), headers: auth
    assert_response :not_found

    assert_equal attributes, @workspace.reload.attributes
  end

  test "foreign memory writes answer 404 and create or change nothing" do
    attributes = @memory.attributes

    assert_no_difference "Memory.count" do
      post workspace_memories_url(workspace_id: @workspace.id, format: :json),
        params: {memory: {title: "Injected", body: "hello"}}, headers: auth
      assert_response :not_found

      post workspace_memory_versions_url(workspace_id: @workspace.id, memory_id: @memory.id, format: :json),
        params: {version: {body: "hello"}}, headers: auth
      assert_response :not_found
    end

    patch workspace_memory_url(workspace_id: @workspace.id, id: @memory.id, format: :json),
      params: {memory: {title: "Hijacked"}}, headers: auth
    assert_response :not_found

    delete workspace_memory_url(workspace_id: @workspace.id, id: @memory.id, format: :json), headers: auth
    assert_response :not_found

    assert_equal attributes, @memory.reload.attributes
  end

  test "foreign link writes answer 404 and create nothing" do
    assert_no_difference "MemoryLink.count" do
      post workspace_memory_links_url(workspace_id: @workspace.id, memory_id: @memory.id, format: :json),
        params: {to_memory_id: @own_memory.id}, headers: auth
      assert_response :not_found

      delete workspace_memory_link_url(workspace_id: @workspace.id, memory_id: @memory.id, id: @own_memory.id, format: :json),
        headers: auth
      assert_response :not_found
    end
  end

  test "linking one's own memory to a foreign memory is rejected as invalid" do
    assert_no_difference "MemoryLink.count" do
      post workspace_memory_links_url(workspace_id: @own_workspace.id, memory_id: @own_memory.id, format: :json),
        params: {to_memory_id: @memory.id}, headers: auth
      assert_response :unprocessable_entity
      assert_equal "VALIDATION_ERROR", json.dig("error", "code")
    end
  end

  # --- Collections -----------------------------------------------------------

  test "collection endpoints never return another account's rows" do
    [
      workspaces_url(format: :json),
      browse_memories_url(format: :json),
      browse_memories_url(format: :json, workspace_id: @workspace.id),
      browse_memories_url(format: :json, ids: [@memory.id, memories(:versioned_parent).id].join(",")),
      pinned_memories_url(format: :json)
    ].each do |path|
      get path, headers: auth
      assert_response :success, path
      assert_empty foreign_rows(json), "#{path} leaked account one rows"
    end
  end

  # Without this the emptiness assertions above could pass because foreign_rows
  # never matches anything, rather than because the rows are absent.
  test "the owning account does see the rows the other account cannot" do
    get browse_memories_url(format: :json, ids: [@memory.id].join(",")),
      headers: {"Authorization" => "Bearer test_full_token_456"}

    assert_response :success
    assert_not_empty foreign_rows(json)
  end

  test "search cannot reach another account" do
    get search_url(format: :json, q: "notes", workspace_id: @workspace.id), headers: auth
    assert_response :not_found
    assert_not_found_body

    get search_url(format: :json, q: @memory.title), headers: auth
    assert_response :success
    assert_empty foreign_rows(json["results"])
  end

  private

  def auth
    {"Authorization" => "Bearer #{@token}"}
  end

  def json
    JSON.parse(response.body)
  end

  def assert_not_found_body
    assert_equal({"error" => {"code" => "NOT_FOUND", "message" => "Resource not found", "status" => 404}}, json)
  end

  # Ids belonging to account one that appear in a payload account two asked for.
  def foreign_rows(rows)
    foreign_workspace_ids = Account.find(@workspace.account_id).workspaces.pluck(:id)
    foreign_memory_ids = Memory.where(workspace_id: foreign_workspace_ids).pluck(:id)

    Array(rows).select do |row|
      foreign_workspace_ids.include?(row["id"]) && row.key?("name") ||
        foreign_memory_ids.include?(row["id"]) && row.key?("title") ||
        foreign_workspace_ids.include?(row.dig("workspace", "id"))
    end
  end
end
