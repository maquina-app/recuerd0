require "test_helper"

class VersioningFlowTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @memory = Memory.create_with_content(@workspace, title: "Deploy notes", content: "first line", created_by: users(:one))
    sign_in_as(users(:one))
  end

  # U-04
  test "each version's markdown URL returns that version, and the memory's the current one" do
    v2 = @memory.create_version!(content: "second line")
    v3 = @memory.create_version!(content: "third line")

    get workspace_memory_version_markdown_url(@workspace, @memory, @memory)
    assert_equal "first line", response.body

    get workspace_memory_version_markdown_url(@workspace, @memory, v2)
    assert_equal "second line", response.body

    get workspace_memory_markdown_url(@workspace, v2)
    assert_equal "second line", response.body

    get workspace_memory_markdown_url(@workspace, @memory)
    assert_equal v3.content.body.content, response.body
  end

  test "View Markdown on an old version's page links to that version" do
    @memory.create_version!(content: "second line")

    get workspace_memory_version_url(@workspace, @memory, @memory)
    assert_response :success
    assert_select "a[href=?]", workspace_memory_version_markdown_path(@workspace, @memory, @memory)
  end

  # U-08
  test "saving as a new version keeps the old text and records the note" do
    patch workspace_memory_url(@workspace, @memory), params: {
      save_as: "new_version",
      memory: {title: "Deploy notes", content: "changed line", change_note: "Fixed the command"}
    }

    assert_redirected_to workspace_memory_url(@workspace, @memory)
    assert_equal I18n.t("memories.update.version_created", version: "v2"), flash[:notice]
    assert_equal "first line", @memory.reload.content.body.content
    current = @memory.current_version
    assert_equal 2, current.version
    assert_equal "changed line", current.content.body.content
    assert_equal "Fixed the command", current.change_note
    assert_equal users(:one), current.created_by
  end

  test "updating in place overwrites the current version and adds none" do
    assert_no_difference("Memory.count") do
      patch workspace_memory_url(@workspace, @memory), params: {
        save_as: "in_place",
        memory: {title: "Deploy notes", content: "overwritten"}
      }
    end

    assert_equal "overwritten", @memory.reload.content.body.content
  end

  test "a plain PATCH still means in place, the REST contract" do
    assert_no_difference("Memory.count") do
      patch workspace_memory_url(@workspace, @memory, format: :json),
        params: {memory: {content: "api edit"}},
        headers: auth_headers("test_full_token_456")
    end
    assert_response :success
    assert_equal "api edit", @memory.reload.content.body.content
  end

  test "the editor offers both, and names what each does" do
    get edit_workspace_memory_url(@workspace, @memory)

    assert_select "button[name='save_as'][value='new_version']", text: I18n.t("memories.form.save_as_new_version")
    assert_select "button[name='save_as'][value='in_place']", text: I18n.t("memories.form.update_in_place", version: "v1")
    assert_select "input[name='memory[change_note]']"
  end

  # U-09
  test "New Version opens the editor rather than making a copy" do
    get workspace_memory_url(@workspace, @memory)

    assert_select "a[href=?]", edit_workspace_memory_path(@workspace, @memory), text: /New Version/
    assert_select "[data-turbo-confirm*='new version']", count: 0
  end

  test "saving a new version with nothing changed is refused" do
    assert_no_difference("Memory.count") do
      patch workspace_memory_url(@workspace, @memory), params: {
        save_as: "new_version",
        memory: {title: "Deploy notes", content: "first line", category: "general"}
      }
    end

    assert_response :unprocessable_entity
    assert_match I18n.t("activerecord.errors.models.memory.attributes.base.no_changes"), response.body
  end

  test "saving a new version cannot blank existing content" do
    assert_no_difference("Memory.count") do
      patch workspace_memory_url(@workspace, @memory), params: {
        save_as: "new_version",
        memory: {title: "Deploy notes", content: ""}
      }
    end

    assert_response :unprocessable_entity
  end

  # U-10
  test "restoring an old version makes it current and says so, without touching the others" do
    v2 = @memory.create_version!(content: "second line")

    get workspace_memory_versions_url(@workspace, @memory)
    assert_select "[data-turbo-confirm=?]", I18n.t("memories.versions.index.restore_confirm", next: "v3", current: "v2")
    assert_no_match(/Branch/, response.body)

    post workspace_memory_version_restoration_url(@workspace, @memory, @memory)

    assert_redirected_to workspace_memory_url(@workspace, @memory)
    assert_equal I18n.t("memories.versions.restorations.create.restored", from: "v1", version: "v3"), flash[:notice]
    current = @memory.reload.current_version
    assert_equal "first line", current.content.body.content
    assert_equal "Restored from v1", current.change_note
    assert_equal "second line", v2.reload.content.body.content
  end

  test "restoring works from any version, and only for a browser session" do
    v2 = @memory.create_version!(content: "second line")
    @memory.create_version!(content: "third line")

    post workspace_memory_version_restoration_url(@workspace, @memory, v2)

    current = @memory.reload.current_version
    assert_equal "second line", current.content.body.content
    assert_equal "Restored from v2", current.change_note
    assert_equal users(:one), current.created_by

    delete session_url
    assert_no_difference("Memory.count") do
      post workspace_memory_version_restoration_url(@workspace, @memory, v2), headers: auth_headers("test_full_token_456")
    end
    assert_response :unauthorized
  end

  test "a read-only workspace refuses a restoration" do
    v2 = @memory.create_version!(content: "second line")
    @workspace.archive

    assert_no_difference("Memory.count") do
      post workspace_memory_version_restoration_url(@workspace, @memory, v2)
    end
  end

  # Omitted fields come from the latest version, not from v1. Two versions needed:
  # with one, the root and the latest are the same row.
  test "REST: omitted fields come from the current version when given the memory's id" do
    latest = @memory.create_version!(title: "Renamed", content: "latest body", source: "newer", category: "decision", tags: ["newer"])

    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {version: {change_note: "No other changes"}},
      headers: auth_headers("test_full_token_456")

    assert_response :created
    created = @memory.reload.current_version
    assert_not_equal latest, created
    assert_equal "Renamed", created.title
    assert_equal "latest body", created.content.body.content
    assert_equal "newer", created.source
    assert_equal "decision", created.category
    assert_equal ["newer"], created.tags
  end

  test "REST: without a change note or a browser, nothing claims to be a restoration" do
    @memory.create_version!(content: "latest body")

    post workspace_memory_versions_url(@workspace, @memory),
      params: {version: {title: "Named"}},
      headers: auth_headers("test_full_token_456").merge("Accept" => "*/*")

    created = @memory.reload.current_version
    assert_equal "latest body", created.content.body.content
    assert_nil created.change_note
  end

  test "REST: a specific version's id still inherits from that version" do
    v2 = @memory.create_version!(title: "Second", content: "second line")
    @memory.create_version!(title: "Third", content: "third line")

    post workspace_memory_versions_url(@workspace, v2, format: :json),
      params: {version: {change_note: "From v2"}},
      headers: auth_headers("test_full_token_456")

    created = @memory.reload.current_version
    assert_equal "Second", created.title
    assert_equal "second line", created.content.body.content
  end

  test "MCP: omitted fields come from the current version" do
    @memory.create_version!(title: "Renamed", content: "latest body", source: "newer", tags: ["newer"])

    result = Mcp::Tools.create_version(accounts(:one), {"memory_id" => @memory.id.to_s, "change_note" => "Note only"}, user: users(:one))

    assert_equal "Renamed", result[:title]
    assert_equal ["newer"], result[:tags]
    assert_equal "latest body", @memory.reload.current_version.content.body.content
  end

  test "MCP: a given field still wins over the inherited one" do
    @memory.create_version!(title: "Renamed", content: "latest body")

    result = Mcp::Tools.create_version(accounts(:one), {"memory_id" => @memory.id.to_s, "content" => "brand new"}, user: users(:one))

    assert_equal "Renamed", result[:title]
    assert_equal "brand new", @memory.reload.current_version.content.body.content
  end

  # U-11
  test "the history shows each version's changes and note, not raw markdown" do
    @memory.create_version!(content: "first line\nadded line", change_note: "Why it changed", created_by: users(:one))

    get workspace_memory_versions_url(@workspace, @memory)

    assert_select ".version-diff summary", text: /Changes from v1/
    assert_select ".vd-added", text: /added line/
    assert_match "Why it changed", response.body
    assert_select "h3", text: "v2"
    assert_select ".ring-primary h3", text: "v2"
  end

  test "REST accepts and returns a change note" do
    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {version: {content: "v2", change_note: "From the API"}},
      headers: auth_headers("test_full_token_456")

    assert_response :created
    assert_equal "From the API", JSON.parse(response.body)["change_note"]
  end

  # U-12
  test "the current version shows the memory's original creation date and its own save date" do
    @memory.update_columns(created_at: 3.days.ago)
    @memory.create_version!(content: "second line")

    get workspace_memory_url(@workspace, @memory)

    assert_match I18n.t("memories.show.created_ago", time: "3 days"), response.body
    assert_match I18n.t("memories.show.version_saved_ago", version: "v2", time: "less than a minute"), response.body
  end

  test "an old version's save date ignores later activity" do
    @memory.update_columns(created_at: 3.days.ago)
    @memory.create_version!(content: "second line")

    get workspace_memory_version_url(@workspace, @memory, @memory)

    assert_match I18n.t("memories.show.version_saved_ago", version: "v1", time: "3 days"), response.body
  end

  test "an old version's edit URL goes to editing the current version" do
    v2 = @memory.create_version!(content: "second line")
    @memory.create_version!(content: "third line")

    get edit_workspace_memory_url(@workspace, v2)
    assert_redirected_to edit_workspace_memory_url(@workspace, @memory)

    follow_redirect!
    assert_response :success
    assert_select "house-md", text: /third line/
  end

  test "links attach to the memory, wherever they were made from" do
    v2 = @memory.create_version!(content: "second line")
    other = memories(:one)

    post workspace_memory_memory_linking_url(@workspace, v2), params: {to_memory_id: other.id}

    assert_includes @memory.reload.linked_memory_ids, other.id
    get workspace_memory_url(@workspace, @memory)
    assert_select "#related-memories .memory-row", text: /#{other.title}/
  end

  # U-14
  test "the link picker searches as you type and stays open with an empty query" do
    get workspace_memory_url(@workspace, @memory)
    assert_select "details#link-picker:not([open])[data-controller='ws-filter']"
    assert_select "input#link-picker-search[data-action*='input->ws-filter#submit']"

    get workspace_memory_url(@workspace, @memory, link_q: "")
    assert_select "details#link-picker[open]"
  end

  # U-43
  test "Add Content asks the editor for focus" do
    empty = Memory.create_with_content(@workspace, title: "No body yet", content: "", created_by: users(:one))

    get workspace_memory_url(@workspace, empty)
    assert_select "a[href=?]", edit_workspace_memory_path(@workspace, empty, focus: "editor")

    get edit_workspace_memory_url(@workspace, empty, focus: "editor")
    assert_select "form[data-memory-editor-focus-editor-value='true']"
  end
end
