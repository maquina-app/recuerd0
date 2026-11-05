require "test_helper"

# Multi-request flows from the 2026-11-05 API test: places where one call's result
# only shows up as wrong in the next one.
class ApiBehaviourTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @headers = auth_headers("test_full_token_456").merge("Content-Type" => "application/json")
    @member_headers = headers_for(users(:member))
  end

  # Tag filters

  test "tag filters ignore case on every list endpoint" do
    memory = Memory.create_with_content(@workspace, title: "Tagged", content: "b", tags: ["Deploy"])

    [
      workspace_memories_url(@workspace, format: :json, tags: "deploy"),
      workspace_memories_url(@workspace, format: :json, tags: "DEPLOY"),
      browse_memories_url(format: :json, tags: "deploy")
    ].each do |path|
      get path, headers: @headers

      assert_includes response.parsed_body.map { |row| row["id"] }, memory.id, path
    end
  end

  test "a tag filter ignores case on obsolete memories too" do
    memory = Memory.create_with_content(@workspace, title: "Old", content: "b", tags: ["Superseded"])

    get workspace_memories_url(@workspace, format: :json, tags: "superseded", include: "obsolete"), headers: @headers

    assert_equal [memory.id], response.parsed_body.map { |row| row["id"] }
  end

  # Title filter

  test "percent and underscore in a title filter are literal" do
    meeting = Memory.create_with_content(@workspace, title: "Zebra Meeting", content: "b")
    percent = Memory.create_with_content(@workspace, title: "100% Zebra", content: "b")

    get workspace_memories_url(@workspace, format: :json, title: "%"), headers: @headers
    assert_empty response.parsed_body

    get workspace_memories_url(@workspace, format: :json, title: "_ebra*"), headers: @headers
    assert_empty response.parsed_body

    get workspace_memories_url(@workspace, format: :json, title: "100%*"), headers: @headers
    assert_equal [percent.id], response.parsed_body.map { |row| row["id"] }

    get workspace_memories_url(@workspace, format: :json, title: "Zebra M?eting"), headers: @headers
    assert_equal [meeting.id], response.parsed_body.map { |row| row["id"] }

    get workspace_memories_url(@workspace, format: :json, title: "*zebra*"), headers: @headers
    assert_equal [meeting.id, percent.id].sort, response.parsed_body.map { |row| row["id"] }.sort
  end

  # Deleted workspaces

  test "a deleted workspace answers 404 on get, update, delete and archive" do
    workspace = create_workspace
    delete workspace_url(workspace, format: :json), headers: @headers
    assert_response :no_content

    get workspace_url(workspace, format: :json), headers: @headers
    assert_response :not_found
    assert_equal "NOT_FOUND", response.parsed_body.dig("error", "code")

    patch workspace_url(workspace, format: :json), params: {workspace: {name: "z"}}.to_json, headers: @headers
    assert_response :not_found

    delete workspace_url(workspace, format: :json), headers: @headers
    assert_response :not_found

    post archive_workspace_url(workspace, format: :json), headers: @headers
    assert_response :not_found
    assert_not workspace.reload.archived_at?, "a deleted workspace must not be archived behind the 404"

    delete archive_workspace_url(workspace, format: :json), headers: @headers
    assert_response :not_found
  end

  test "a deleted workspace stays exportable and restorable in the browser" do
    workspace = create_workspace
    delete workspace_url(workspace, format: :json), headers: @headers

    get workspace_export_url(workspace, format: :json), headers: @headers
    assert_response :success

    sign_in_as users(:one)
    post restore_deleted_workspace_url(workspace)
    assert_not workspace.reload.deleted?

    get workspace_url(workspace, format: :json), headers: @headers
    assert_response :success
    assert_equal "active", response.parsed_body["state"]
  end

  test "a workspace reports its state" do
    get workspace_url(workspaces(:archived), format: :json), headers: @headers
    assert_equal "archived", response.parsed_body["state"]

    get workspace_url(@workspace, format: :json), headers: @headers
    assert_equal "active", response.parsed_body["state"]
  end

  # Context and the seeded Map

  test "context on a new workspace returns the Map and the workspace's memories" do
    workspace = create_workspace
    3.times { |n| Memory.create_with_content(workspace, title: "Memory #{n}", content: "b") }

    get workspace_context_url(workspace, format: :json), headers: @headers

    assert_response :success
    json = response.parsed_body
    assert_equal "recent", json["context_source"]
    assert_equal 4, json["memories"].size
    assert_equal WorkspaceStarter.attributes(base_url: "https://example.com")[:title], json["memories"].first["title"]
    assert_equal 1, json.dig("stats", "total_pinned")
  end

  test "context for a member with only the auto-pin behaves the same" do
    workspace = create_workspace
    Memory.create_with_content(workspace, title: "Content", content: "b")

    get workspace_context_url(workspace, format: :json), headers: @member_headers

    json = response.parsed_body
    assert_equal "recent", json["context_source"]
    assert_equal 2, json["memories"].size
  end

  test "context respects limit when topping up" do
    workspace = create_workspace
    3.times { |n| Memory.create_with_content(workspace, title: "Memory #{n}", content: "b") }

    get workspace_context_url(workspace, format: :json, limit: 2), headers: @headers
    assert_equal 2, response.parsed_body["memories"].size

    get workspace_context_url(workspace, format: :json, limit: 1), headers: @headers
    assert_equal 1, response.parsed_body["memories"].size
  end

  test "a pin the user chose still decides the context" do
    workspace = create_workspace
    chosen = Memory.create_with_content(workspace, title: "Chosen", content: "b")
    Memory.create_with_content(workspace, title: "Not chosen", content: "b")
    chosen.pin!(users(:one))

    get workspace_context_url(workspace, format: :json), headers: @headers

    json = response.parsed_body
    assert_equal "pins", json["context_source"]
    assert_includes json["memories"].map { |memory| memory["title"] }, "Chosen"
    assert_not_includes json["memories"].map { |memory| memory["title"] }, "Not chosen"
  end

  test "start_with_map false creates a workspace with no Map" do
    [false, "0", "false"].each do |value|
      post workspaces_url(format: :json),
        params: {workspace: {name: "Bare", start_with_map: value}}.to_json, headers: @headers

      assert_response :created, value.inspect
      assert_equal 0, response.parsed_body["memories_count"], value.inspect
      assert_empty Workspace.find(response.parsed_body["id"]).memories, value.inspect
    end
  end

  test "a workspace gets the Map unless it opts out" do
    post workspaces_url(format: :json), params: {workspace: {name: "Default"}}.to_json, headers: @headers

    assert_equal 1, response.parsed_body["memories_count"]
  end

  # Blank versions

  test "a blank version is refused and leaves the memory alone" do
    memory = Memory.create_with_content(@workspace, title: "Keep", content: "the text")

    ["", "   "].each do |blank|
      assert_no_difference "Memory.count" do
        post workspace_memory_versions_url(@workspace, memory, format: :json),
          params: {version: {content: blank}}.to_json, headers: @headers
      end

      assert_response :unprocessable_entity, blank.inspect
    end

    assert_equal "the text", memory.reload.current_version.content.body.content
  end

  test "a version that omits content still inherits it" do
    memory = Memory.create_with_content(@workspace, title: "Keep", content: "the text")

    post workspace_memory_versions_url(@workspace, memory, format: :json),
      params: {version: {title: "Renamed"}}.to_json, headers: @headers

    assert_response :created
    assert_equal "the text", response.parsed_body.dig("content", "body")
  end

  # Paging past the end

  test "a page past the end is empty on every list, and its headers stay honest" do
    [
      workspaces_url(format: :json, page: 999),
      workspace_memories_url(@workspace, format: :json, page: 999),
      browse_memories_url(format: :json, page: 999)
    ].each do |path|
      get path, headers: @headers

      assert_response :success, path
      assert_empty response.parsed_body, path
      assert_equal "999", response.headers["X-Page"], path
      assert_not_includes response.headers["Link"], %(rel="next"), path
    end

    Memory.create_with_content(@workspace, title: "Findable zebrafinch", content: "b").rebuild_search_index
    get search_url(format: :json, q: "zebrafinch", page: 999), headers: @headers
    assert_empty response.parsed_body["results"]
  end

  test "a browser past the last page still lands on the last page" do
    sign_in_as users(:one)

    get workspaces_url(page: 999)

    assert_response :success
    assert_not_empty @controller.view_assigns["workspaces"].to_a
  end

  # Archived workspaces are read-only

  test "links can't be made or removed from an archived memory" do
    archived = workspaces(:archived)
    memory = Memory.create_with_content(archived, title: "Frozen", content: "b")
    other = Memory.create_with_content(@workspace, title: "Live", content: "b")

    assert_no_difference "MemoryLink.count" do
      post workspace_memory_links_url(archived, memory, format: :json),
        params: {to_memory_id: other.id}.to_json, headers: @headers
    end
    assert_response :forbidden
    assert_equal "FORBIDDEN", response.parsed_body.dig("error", "code")

    MemoryLink.create!(from_memory: memory, to_memory: other)

    assert_no_difference "MemoryLink.count" do
      delete workspace_memory_link_url(archived, memory, other, format: :json), headers: @headers
    end
    assert_response :forbidden

    get workspace_memory_links_url(archived, memory, format: :json), headers: @headers
    assert_response :success
  end

  test "the browser's unlink on an archived memory redirects with 303" do
    sign_in_as users(:one)
    archived = workspaces(:archived)
    memory = Memory.create_with_content(archived, title: "Frozen", content: "b")
    other = Memory.create_with_content(@workspace, title: "Live", content: "b")
    MemoryLink.create!(from_memory: memory, to_memory: other)

    delete workspace_memory_memory_linking_remove_url(archived, memory, other_id: other.id)

    assert_response :see_other
    assert MemoryLink.exists?(from_memory_id: [memory.id, other.id].min)
  end

  test "a link can not change when only the other memory is archived" do
    archived = workspaces(:archived)
    frozen = Memory.create_with_content(archived, title: "Frozen", content: "b")
    live = Memory.create_with_content(@workspace, title: "Live", content: "b")

    assert_no_difference "MemoryLink.count" do
      post workspace_memory_links_url(@workspace, live, format: :json),
        params: {to_memory_id: frozen.id}.to_json, headers: @headers
    end
    assert_response :forbidden
    assert_equal I18n.t("memories.links.other_archived"), response.parsed_body.dig("error", "message")

    MemoryLink.create!(from_memory: live, to_memory: frozen)

    assert_no_difference "MemoryLink.count" do
      delete workspace_memory_link_url(@workspace, live, frozen, format: :json), headers: @headers
    end
    assert_response :forbidden
  end

  test "the browser refuses a link change when only the other memory is archived" do
    sign_in_as users(:one)
    frozen = Memory.create_with_content(workspaces(:archived), title: "Frozen", content: "b")
    live = Memory.create_with_content(@workspace, title: "Live", content: "b")

    assert_no_difference "MemoryLink.count" do
      post workspace_memory_memory_linking_url(@workspace, live), params: {to_memory_id: frozen.id}
    end
    assert_response :see_other
    assert_equal I18n.t("memories.links.other_archived"), flash[:alert]

    MemoryLink.create!(from_memory: live, to_memory: frozen)

    assert_no_difference "MemoryLink.count" do
      delete workspace_memory_memory_linking_remove_url(@workspace, live, other_id: frozen.id)
    end
    assert_response :see_other
    assert_equal I18n.t("memories.links.other_archived"), flash[:alert]
  end

  test "the page hides removal of a link to an archived memory" do
    sign_in_as users(:one)
    frozen = Memory.create_with_content(workspaces(:archived), title: "Frozen", content: "b")
    linked = Memory.create_with_content(@workspace, title: "Linked", content: "b")
    live = Memory.create_with_content(@workspace, title: "Live", content: "b")
    MemoryLink.create!(from_memory: live, to_memory: frozen, created_by: users(:one))
    MemoryLink.create!(from_memory: live, to_memory: linked, created_by: users(:one))

    get workspace_memory_url(@workspace, live)

    assert_response :success
    assert_select "form[action=?]", workspace_memory_memory_linking_remove_path(@workspace, live, other_id: linked.id)
    assert_select "form[action=?]", workspace_memory_memory_linking_remove_path(@workspace, live, other_id: frozen.id), count: 0
  end

  test "the picker only offers memories in active workspaces" do
    sign_in_as users(:one)
    live = Memory.create_with_content(@workspace, title: "Live", content: "b")
    Memory.create_with_content(@workspace, title: "Quillbeacon active", content: "b").rebuild_search_index
    Memory.create_with_content(workspaces(:archived), title: "Quillbeacon archived", content: "b").rebuild_search_index
    Memory.create_with_content(workspaces(:deleted), title: "Quillbeacon deleted", content: "b").rebuild_search_index

    get workspace_memory_url(@workspace, live, link_q: "quillbeacon")

    assert_select ".link-picker .mr-title", text: "Quillbeacon active"
    assert_select ".link-picker .mr-title", text: /archived|deleted/, count: 0
  end

  test "a link to an archived memory says why it can't be removed" do
    sign_in_as users(:one)
    frozen = Memory.create_with_content(workspaces(:archived), title: "Frozen", content: "b")
    linked = Memory.create_with_content(@workspace, title: "Linked", content: "b")
    live = Memory.create_with_content(@workspace, title: "Live", content: "b")
    MemoryLink.create!(from_memory: live, to_memory: frozen, created_by: users(:one))
    MemoryLink.create!(from_memory: live, to_memory: linked, created_by: users(:one))

    get workspace_memory_url(@workspace, live)

    hint = I18n.t("memories.links.archived_other_hint")
    assert_select "li.memory-row", text: /Frozen/ do
      assert_select ".mr-elsewhere-static", text: hint
    end
    assert_select "li.memory-row", text: /Linked/ do
      assert_select ".mr-elsewhere-static", text: hint, count: 0
    end
  end

  # Values from before the limits existed

  test "a new version isn't refused over a source or tags it inherits" do
    memory = Memory.create_with_content(@workspace, title: "Older", content: "b")
    memory.update_columns(source: "s" * 420, tags: Array.new(60) { |n| "tag#{n}" })

    post workspace_memory_versions_url(@workspace, memory, format: :json),
      params: {version: {content: "one more sentence"}}.to_json, headers: @headers

    assert_response :created
    assert_equal 420, response.parsed_body["source"].length
    assert_equal 60, response.parsed_body["tags"].length
  end

  test "a member's new version isn't refused over an inherited source either" do
    memory = Memory.create_with_content(@workspace, title: "Older", content: "b")
    memory.update_columns(source: "s" * 420)

    post workspace_memory_versions_url(@workspace, memory, format: :json),
      params: {version: {content: "one more sentence"}}.to_json, headers: @member_headers

    assert_response :created
  end

  test "a value sent in the request is still held to the limit" do
    memory = Memory.create_with_content(@workspace, title: "Older", content: "b")
    memory.update_columns(source: "s" * 420, tags: Array.new(60) { |n| "tag#{n}" })

    post workspace_memory_versions_url(@workspace, memory, format: :json),
      params: {version: {content: "c", source: "t" * 256}}.to_json, headers: @headers
    assert_response :unprocessable_entity

    post workspace_memory_versions_url(@workspace, memory, format: :json),
      params: {version: {content: "c", tags: Array.new(51) { |n| "new#{n}" }}}.to_json, headers: @headers
    assert_response :unprocessable_entity
  end

  test "the form shows a tag limit error, and saves a new version over untouched values" do
    sign_in_as users(:one)
    memory = Memory.create_with_content(@workspace, title: "Older", content: "b")
    tags = Array.new(60) { |n| "tag#{n}" }
    memory.update_columns(source: "s" * 420, tags: tags)

    patch workspace_memory_url(@workspace, memory),
      params: {save_as: "new_version", memory: {title: "Older", content: "more", source: "s" * 420, tags: tags}}
    assert_response :see_other
    assert_equal 2, memory.reload.current_version.version

    patch workspace_memory_url(@workspace, memory),
      params: {save_as: "new_version", memory: {title: "Older", content: "more again", source: "s" * 420, tags: tags + ["one more"]}}
    assert_response :unprocessable_entity
    assert_select "[data-form-part=error]", text: /Tags are limited to 50/
  end

  test "a refused new version keeps everything the person typed" do
    sign_in_as users(:one)
    memory = Memory.create_with_content(@workspace, title: "Saved title", content: "saved body")

    patch workspace_memory_url(@workspace, memory),
      params: {save_as: "new_version", memory: {title: "Typed title", content: "typed body", source: "t" * 256, tags: ["typed tag"]}}

    assert_response :unprocessable_entity
    assert_select "[data-form-part=error]", text: /too long/
    assert_includes response.body, "Typed title"
    assert_includes response.body, "typed body"
    assert_includes response.body, "typed tag"
    assert_includes response.body, "t" * 256
    assert_equal "Saved title", memory.reload.title
    assert_equal 1, memory.current_version.version
  end

  # Bad requests from a browser

  test "a browser with a bad page gets the first page" do
    sign_in_as users(:one)

    [
      "#{workspaces_url}?page=0",
      "#{workspaces_url}?page=abc",
      "#{workspaces_url}?page[]=1",
      "#{workspaces_url}?page=9223372036854775807",
      "#{search_url}?q=note&page=0",
      "#{search_url}?q=note&page[]=1",
      "#{workspace_url(@workspace)}?page=0"
    ].each do |url|
      get url

      assert_response :success, url
    end
  end

  test "a browser form replayed with a null character gets a 400, not a 500" do
    sign_in_as users(:one)

    assert_no_difference "Memory.count" do
      post workspace_memories_url(@workspace), params: {memory: {title: "a\u0000b", content: "c"}}
    end
    assert_response :bad_request
  end

  # Short words in a search

  test "a short word doesn't stop a search finding the rest" do
    memory = Memory.create_with_content(@workspace, title: "How to deploy the app", content: "b")
    memory.rebuild_search_index

    get search_url(format: :json, q: "how to deploy"), headers: @headers

    assert_response :success
    assert_equal [memory.id], response.parsed_body["results"].map { |result| result["id"] }
    assert_equal ["to"], response.parsed_body["ignored_words"]
  end

  test "a memory can be found by its exact title when that has short words" do
    memory = Memory.create_with_content(@workspace, title: "M2 in AdminWS", content: "b")
    memory.rebuild_search_index

    get search_url(format: :json, q: "M2 in AdminWS"), headers: @headers

    assert_equal [memory.id], response.parsed_body["results"].map { |result| result["id"] }
    assert_equal %w[M2 in], response.parsed_body["ignored_words"]
  end

  test "a search with no short words ignores nothing" do
    get search_url(format: :json, q: "deploy app"), headers: @headers

    assert_equal [], response.parsed_body["ignored_words"]
  end

  test "a search of only short words finds nothing and says why" do
    get search_url(format: :json, q: "to in"), headers: @headers

    assert_response :success
    assert_empty response.parsed_body["results"]
    assert_equal %w[to in], response.parsed_body["ignored_words"]
  end

  test "a quoted phrase stays strict" do
    Memory.create_with_content(@workspace, title: "How to deploy the app", content: "b").rebuild_search_index

    get search_url(format: :json, q: %("to" deploy)), headers: @headers

    assert_empty response.parsed_body["results"]
    assert_empty response.parsed_body["ignored_words"]
  end

  test "the web says which words it left out, wherever a search happens" do
    sign_in_as users(:one)
    memory = Memory.create_with_content(@workspace, title: "How to deploy the app", content: "b")
    memory.rebuild_search_index
    other = Memory.create_with_content(@workspace, title: "Other", content: "b")
    notice = I18n.t("search.ignored_words", words: %("to"), minimum: 3)

    get search_url(q: "how to deploy")
    assert_select "p:not(.sr-only)", text: notice
    assert_select "a", text: "How to deploy the app"

    get search_url(q: "how to deploy"), headers: {"Turbo-Frame" => SearchController::PALETTE_FRAME_ID}
    assert_select "p", text: notice

    get workspace_url(@workspace, q: "how to deploy")
    assert_select "p", text: notice

    get workspace_memory_url(@workspace, other, link_q: "how to deploy")
    assert_select ".link-picker p", text: notice
    assert_select ".link-picker .mr-title", text: "How to deploy the app"
  end

  test "the web says nothing when no word was left out" do
    sign_in_as users(:one)

    get search_url(q: "deploy app")

    assert_select "p", text: /Left out/, count: 0
  end

  # Reading versions

  test "versions can be listed and read one by one" do
    root, old, current = memory_with_three_versions

    get workspace_memory_versions_url(@workspace, root, format: :json), headers: @headers
    assert_response :success
    json = response.parsed_body
    assert_equal [1, 2, 3], json.map { |version| version["version"] }
    assert_equal [root.id, old.id, current.id], json.map { |version| version["id"] }
    assert_equal [false, false, true], json.map { |version| version["current"] }
    assert_not json.first.key?("pinned")

    get workspace_memory_version_url(@workspace, root, old, format: :json), headers: @headers
    assert_response :success
    assert_equal 2, response.parsed_body["version"]
    assert_equal false, response.parsed_body["current"]
    assert_equal "v2", response.parsed_body.dig("content", "body")
  end

  test "a read-only token can read versions, and another account's are 404" do
    root, = memory_with_three_versions

    get workspace_memory_versions_url(@workspace, root, format: :json), headers: auth_headers("test_read_token_123")
    assert_response :success

    get workspace_memory_versions_url(@workspace, root, format: :json), headers: auth_headers("other_user_token_789")
    assert_response :not_found
  end

  test "ids accepts any version's id and returns the current version" do
    root, old, current = memory_with_three_versions

    [root, old, current].each do |version|
      get browse_memories_url(format: :json, ids: version.id.to_s), headers: @headers

      assert_equal [current.id], response.parsed_body.map { |row| row["id"] }, "id #{version.id}"
    end

    get browse_memories_url(format: :json, ids: "#{root.id},#{old.id},#{current.id}"), headers: @headers
    assert_equal 1, response.parsed_body.size
  end

  test "ids can't reach another account through a version" do
    foreign = Memory.create_with_content(workspaces(:two), title: "Foreign", content: "b")
    version = foreign.create_version!(content: "v2")

    get browse_memories_url(format: :json, ids: version.id.to_s), headers: @headers

    assert_empty response.parsed_body
  end

  # Who may remove a link

  test "a member can't remove a link an admin created" do
    a, b = two_memories
    post workspace_memory_links_url(@workspace, a, format: :json), params: {to_memory_id: b.id}.to_json, headers: @headers
    assert_response :created
    assert_equal users(:one), MemoryLink.last.created_by

    assert_no_difference "MemoryLink.count" do
      delete workspace_memory_link_url(@workspace, a, b, format: :json), headers: @member_headers
    end
    assert_response :forbidden
    assert_equal "FORBIDDEN", response.parsed_body.dig("error", "code")
  end

  test "the rule holds from the other side of the link too" do
    a, b = two_memories
    post workspace_memory_links_url(@workspace, a, format: :json), params: {to_memory_id: b.id}.to_json, headers: @headers

    delete workspace_memory_link_url(@workspace, b, a, format: :json), headers: @member_headers

    assert_response :forbidden
  end

  test "a member can remove a link they created" do
    a, b = two_memories
    post workspace_memory_links_url(@workspace, a, format: :json), params: {to_memory_id: b.id}.to_json, headers: @member_headers
    assert_response :created

    assert_difference "MemoryLink.count", -1 do
      delete workspace_memory_link_url(@workspace, a, b, format: :json), headers: @member_headers
    end
    assert_response :no_content
  end

  test "an admin can remove a member's link" do
    a, b = two_memories
    post workspace_memory_links_url(@workspace, a, format: :json), params: {to_memory_id: b.id}.to_json, headers: @member_headers

    assert_difference "MemoryLink.count", -1 do
      delete workspace_memory_link_url(@workspace, a, b, format: :json), headers: @headers
    end
    assert_response :no_content
  end

  test "a link with no recorded creator belongs to the admin" do
    a, b = two_memories
    MemoryLink.create!(from_memory: a, to_memory: b)

    delete workspace_memory_link_url(@workspace, a, b, format: :json), headers: @member_headers
    assert_response :forbidden

    assert_difference "MemoryLink.count", -1 do
      delete workspace_memory_link_url(@workspace, a, b, format: :json), headers: @headers
    end
  end

  test "removing the creator hands their link to the admin" do
    a, b = two_memories
    member = users(:member)
    link = MemoryLink.create!(from_memory: a, to_memory: b, created_by: member)

    member.sessions.destroy_all
    member.access_tokens.destroy_all
    member.pins.destroy_all
    member.destroy!

    assert_nil link.reload.created_by_id
  end

  test "the browser hides and refuses removal for a member, and allows the creator" do
    a, b = two_memories
    c = Memory.create_with_content(@workspace, title: "C", content: "b")
    MemoryLink.create!(from_memory: a, to_memory: b, created_by: users(:one))
    MemoryLink.create!(from_memory: a, to_memory: c, created_by: users(:member))

    sign_in_as users(:member)

    get workspace_memory_url(@workspace, a)
    assert_response :success
    assert_select "form[action=?]", workspace_memory_memory_linking_remove_path(@workspace, a, other_id: b.id), count: 0
    assert_select "form[action=?]", workspace_memory_memory_linking_remove_path(@workspace, a, other_id: c.id), count: 1

    assert_no_difference "MemoryLink.count" do
      delete workspace_memory_memory_linking_remove_url(@workspace, a, other_id: b.id)
    end
    assert_response :see_other
    assert_equal I18n.t("memories.links.remove_denied"), flash[:alert]

    assert_difference "MemoryLink.count", -1 do
      delete workspace_memory_memory_linking_remove_url(@workspace, a, other_id: c.id)
    end
    assert_response :see_other
  end

  test "the browser records who made a link and shows an admin every remove button" do
    a, b = two_memories

    sign_in_as users(:one)
    post workspace_memory_memory_linking_url(@workspace, a), params: {to_memory_id: b.id}
    assert_equal users(:one), MemoryLink.last.created_by

    get workspace_memory_url(@workspace, a)
    assert_select "form[action=?]", workspace_memory_memory_linking_remove_path(@workspace, a, other_id: b.id), count: 1
  end

  private

  def headers_for(user)
    token = AccessToken.create!(user: user, description: "member", permission: "full_access")
    auth_headers(token.raw_token).merge("Content-Type" => "application/json")
  end

  def memory_with_three_versions(title: "Versioned")
    root = Memory.create_with_content(@workspace, title: title, content: "v1")
    old = root.create_version!(content: "v2")
    current = root.create_version!(content: "v3")
    [root.reload, old, current]
  end

  def two_memories
    [
      Memory.create_with_content(@workspace, title: "A", content: "b"),
      Memory.create_with_content(@workspace, title: "B", content: "b")
    ]
  end

  def create_workspace
    post workspaces_url(format: :json), params: {workspace: {name: "Fresh #{SecureRandom.hex(3)}"}}.to_json, headers: @headers
    assert_response :created
    Workspace.find(response.parsed_body["id"])
  end
end
