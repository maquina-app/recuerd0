require "test_helper"

class Memories::Versions::PurgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @root = Memory.create_with_content(@workspace, title: "Runbook v1", content: "first")
    (2..4).each { |n| @root.create_version!(title: "Runbook v#{n}", content: "body #{n}") }
    @current = @root.current_version
    sign_in_as(@user)
  end

  test "new previews keeping the latest N" do
    get new_workspace_memory_versions_purge_url(@workspace, @root, keep: 2)

    assert_response :success
    assert_select "input[name=keep][value='2'][max='3']"
    assert_select "[data-component=alert][data-variant=warning]", text: /permanently deletes 2 versions/
    assert_select "input[type=hidden][name=current_version_id][value='#{@current.id}']"
    assert_select "button[data-turbo-confirm='v1–v2 will be deleted for good; v3–v4 will remain.']"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
  end

  test "new falls back to keep 1 for a missing or out of range value" do
    [nil, "0", "4", "abc"].each do |keep|
      get new_workspace_memory_versions_purge_url(@workspace, @root, keep: keep)

      assert_response :success
      assert_select "input[name=keep][value='1']"
    end
  end

  test "new opened from a version previews the whole memory" do
    get new_workspace_memory_versions_purge_url(@workspace, @current, keep: 1)

    assert_response :success
    assert_select "[data-component=alert][data-variant=warning]", text: /permanently deletes 3 versions/
  end

  test "new redirects when there is only one version" do
    single = memories(:one)

    get new_workspace_memory_versions_purge_url(@workspace, single)

    assert_redirected_to workspace_memory_url(@workspace, single)
    assert_equal I18n.t("memories.versions.purges.nothing_to_purge"), flash[:alert]
  end

  test "new redirects from an archived workspace" do
    @workspace.update!(archived_at: Time.current)

    get new_workspace_memory_versions_purge_url(@workspace, @root)

    assert_redirected_to workspace_memory_url(@workspace, @root)
    assert_equal I18n.t("memories.versions.read_only"), flash[:alert]
  end

  test "create purges and lands on the versions page" do
    assert_difference("Memory.count", -2) do
      perform_enqueued_jobs only: Analytics::RecordEventJob do
        post workspace_memory_versions_purge_url(@workspace, @root), params: {keep: 2, current_version_id: @current.id}
      end
    end

    assert_redirected_to workspace_memory_versions_url(@workspace, @root)
    assert_equal "Deleted 2 versions. Kept v3–v4.", flash[:notice]
    assert_equal [3, 4], @root.reload.all_versions.pluck(:version)

    event = Analytics::Event.find_by(event_type: "version.purge")
    assert_equal({"kept" => 2, "deleted" => 2}, event.metadata)
  end

  test "create with keep out of range re-renders with the field error" do
    assert_no_difference("Memory.count") do
      post workspace_memory_versions_purge_url(@workspace, @root), params: {keep: 4, current_version_id: @current.id}
    end

    assert_response :unprocessable_entity
    assert_select "input[name=keep][aria-invalid=true][value='4']"
    assert_select "p[data-form-part=error]", text: "Enter a number from 1 to 3."
  end

  test "create refuses a stale preview" do
    newer = @root.create_version!(content: "added by an agent")

    assert_no_difference("Memory.count") do
      post workspace_memory_versions_purge_url(@workspace, @root), params: {keep: 1, current_version_id: @current.id}
    end

    assert_response :unprocessable_entity
    assert_select "[data-component=alert][data-variant=destructive]", text: /nothing was deleted/
    assert_select "input[type=hidden][name=current_version_id][value='#{newer.id}']"
  end

  test "another account's memory is not found" do
    other = Memory.create_with_content(workspaces(:two), title: "Theirs", content: "x")
    other.create_version!(content: "y")

    get new_workspace_memory_versions_purge_url(workspaces(:two), other)
    assert_response :not_found

    assert_no_difference("Memory.count") do
      post workspace_memory_versions_purge_url(workspaces(:two), other), params: {keep: 1, current_version_id: other.current_version.id}
    end
    assert_response :not_found
  end

  test "memory actions offer purge on a versioned memory, also on an old version" do
    get workspace_memory_url(@workspace, @root.all_versions.second)

    assert_select "a[href='#{new_workspace_memory_versions_purge_path(@workspace, @root)}']", text: /Purge versions/
  end

  test "versions page links to purge" do
    get workspace_memory_versions_url(@workspace, @root)

    assert_select "a[href='#{new_workspace_memory_versions_purge_path(@workspace, @root)}']", text: /Purge versions/
  end
end
