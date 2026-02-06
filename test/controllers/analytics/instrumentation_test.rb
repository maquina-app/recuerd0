require "test_helper"

class Analytics::InstrumentationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @full_access_token = "test_full_token_456"
    @read_only_token = "test_read_token_123"
  end

  # Memory tracking

  test "memory show creates memory.view event via JSON" do
    perform_enqueued_jobs do
      get workspace_memory_url(@workspace, @memory, format: :json),
        headers: auth_headers(@read_only_token)
    end

    event = Analytics::Event.find_by(event_type: "memory.view")
    assert_not_nil event
    assert_equal "Memory", event.resource_type
    assert_equal @memory.id, event.resource_id
    assert_equal @user.account.id, event.account_id
  end

  test "memory create success creates memory.create event via JSON" do
    perform_enqueued_jobs do
      post workspace_memories_url(@workspace, format: :json),
        headers: auth_headers(@full_access_token),
        params: {memory: {title: "Analytics Test", content: "Body text", tags: []}}
    end

    assert_response :created
    event = Analytics::Event.find_by(event_type: "memory.create")
    assert_not_nil event
    assert_equal "Memory", event.resource_type
  end

  test "memory update via JSON creates memory.update event" do
    perform_enqueued_jobs do
      patch workspace_memory_url(@workspace, @memory, format: :json),
        headers: auth_headers(@full_access_token),
        params: {memory: {title: "Updated via API"}}
    end

    event = Analytics::Event.find_by(event_type: "memory.update")
    assert_not_nil event
    assert_equal "Memory", event.resource_type
    assert_equal @memory.id, event.resource_id
  end

  test "memory destroy creates memory.destroy event via JSON" do
    perform_enqueued_jobs do
      delete workspace_memory_url(@workspace, @memory, format: :json),
        headers: auth_headers(@full_access_token)
    end

    assert_response :no_content
    event = Analytics::Event.find_by(event_type: "memory.destroy")
    assert_not_nil event
    assert_equal "Memory", event.resource_type
  end

  # Workspace tracking

  test "workspace show creates workspace.view event via HTML" do
    sign_in_as(@user)

    perform_enqueued_jobs do
      get workspace_url(@workspace)
    end

    event = Analytics::Event.find_by(event_type: "workspace.view")
    assert_not_nil event
    assert_equal "Workspace", event.resource_type
    assert_equal @workspace.id, event.resource_id
  end

  test "workspace create via JSON creates workspace.create event" do
    perform_enqueued_jobs do
      post workspaces_url(format: :json),
        headers: auth_headers(@full_access_token),
        params: {workspace: {name: "Analytics Workspace", description: "test"}}
    end

    assert_response :created
    event = Analytics::Event.find_by(event_type: "workspace.create")
    assert_not_nil event
    assert_equal "Workspace", event.resource_type
  end

  test "workspace destroy via JSON creates both destroy event and api request" do
    perform_enqueued_jobs do
      delete workspace_url(@workspace, format: :json),
        headers: auth_headers(@full_access_token)
    end

    assert_response :no_content

    event = Analytics::Event.find_by(event_type: "workspace.destroy")
    assert_not_nil event
    assert_equal "Workspace", event.resource_type

    api_request = Analytics::ApiRequest.find_by(http_method: "DELETE")
    assert_not_nil api_request
    assert_includes api_request.path, "/workspaces/"
    assert_equal 204, api_request.status
  end

  # Archive tracking

  test "archive create creates workspace.archive event via JSON" do
    perform_enqueued_jobs do
      post archive_workspace_url(@workspace, format: :json),
        headers: auth_headers(@full_access_token)
    end

    event = Analytics::Event.find_by(event_type: "workspace.archive")
    assert_not_nil event
    assert_equal "Workspace", event.resource_type
    assert_equal @workspace.id, event.resource_id
  end

  # Search tracking

  test "search creates search.query event with metadata via JSON" do
    @memory.rebuild_search_index

    perform_enqueued_jobs do
      get search_url(format: :json, q: "test query"),
        headers: auth_headers(@read_only_token)
    end

    event = Analytics::Event.find_by(event_type: "search.query")
    assert_not_nil event
    assert_equal "test query", event.metadata["query"]
    assert_kind_of Integer, event.metadata["results_count"]
  end

  # Auth tracking

  test "successful sign-in creates auth.sign_in event" do
    perform_enqueued_jobs do
      post session_url, params: {email_address: @user.email_address, password: "password"}
    end

    event = Analytics::Event.find_by(event_type: "auth.sign_in")
    assert_not_nil event
    assert_equal @user.id, event.user_id
  end

  test "failed sign-in creates auth.sign_in_failed event with hashed email" do
    perform_enqueued_jobs do
      post session_url, params: {email_address: @user.email_address, password: "wrong"}
    end

    event = Analytics::Event.find_by(event_type: "auth.sign_in_failed")
    assert_not_nil event
    assert event.metadata["email_hash"].present?
    assert_equal 12, event.metadata["email_hash"].length
  end

  test "failed sign-in with unknown email has nil user_id" do
    perform_enqueued_jobs do
      post session_url, params: {email_address: "nobody@example.com", password: "wrong"}
    end

    event = Analytics::Event.find_by(event_type: "auth.sign_in_failed")
    assert_not_nil event
    assert_nil event.user_id
  end

  test "failed API token creates auth.token_failed event" do
    perform_enqueued_jobs do
      get workspace_memories_url(@workspace, format: :json),
        headers: auth_headers("invalid_token_xyz")
    end

    assert_response :unauthorized

    event = Analytics::Event.find_by(event_type: "auth.token_failed")
    assert_not_nil event
    assert_nil event.user_id
  end

  # Pin tracking

  test "pin create creates pin.create event" do
    sign_in_as(@user)
    workspace = @user.account.workspaces.create!(name: "Pinnable Workspace")

    perform_enqueued_jobs do
      post create_pin_url(pinnable_type: "Workspace", pinnable_id: workspace.id)
    end

    event = Analytics::Event.find_by(event_type: "pin.create")
    assert_not_nil event
    assert_equal "Workspace", event.resource_type
    assert_equal workspace.id, event.resource_id
  end

  # API request tracking

  test "API request tracking captures correct duration_ms" do
    perform_enqueued_jobs do
      get workspace_memories_url(@workspace, format: :json),
        headers: auth_headers(@read_only_token)
    end

    api_request = Analytics::ApiRequest.last
    assert_not_nil api_request
    assert api_request.duration_ms >= 0
    assert api_request.duration_ms < 10_000, "Duration should be reasonable (< 10s)"
  end

  test "analytics job failure does not affect controller response" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success

    assert_nothing_raised do
      Analytics::RecordEventJob.perform_now({event_type: nil})
    end
  end
end
