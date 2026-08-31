require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @archived_workspace = workspaces(:archived)
    @deleted_workspace = workspaces(:deleted)

    sign_in_as(@user)
  end

  # -- index --

  # -- no turbo frames on the list pages --
  #
  # The list used to be wrapped in turbo_frame_tag "workspaces_list". Every link
  # inside it (a workspace, Edit, "search everywhere") is frame-scoped by
  # inheritance, and none of those targets has a matching frame, so each one
  # failed with "Content missing". Filtering now morphs the whole page instead.

  test "index renders no turbo frame" do
    get workspaces_url
    assert_response :success
    assert_select "turbo-frame#workspaces_list", count: 0
  end

  test "workspace links on the index are plain links, not frame-scoped" do
    get workspaces_url
    assert_response :success

    assert_select "a.ws-row-link[href=?]", workspace_path(@workspace)
    assert_select "a.ws-row-link[data-turbo-frame]", count: 0
  end

  test "index filter form drives the page, not a frame" do
    get workspaces_url
    assert_response :success

    # replace (not advance) is what makes the same-pathname visit morph.
    assert_select "form.ws-filter[data-turbo-action=replace]"
    assert_select "form.ws-filter[data-turbo-frame]", count: 0
  end

  test "index filters workspaces by query" do
    match = Workspace.create!(account: @user.account, name: "Zebra Notes")

    get workspaces_url(q: "Zebra")
    assert_response :success

    names = @controller.view_assigns["workspaces"].map(&:name)
    assert_includes names, match.name
    assert_equal 1, names.size
    assert_operator @controller.view_assigns["total"], :>, 1,
      "total must report the unfiltered count so the header can say 1 of N"
  end

  test "index renders the filter empty state when nothing matches" do
    get workspaces_url(q: "zzzznotarealworkspace")
    assert_response :success

    assert_empty @controller.view_assigns["workspaces"].to_a
    assert_select "turbo-frame#workspaces_list", count: 0
  end

  test "index defaults view mode to list" do
    get workspaces_url
    assert_response :success
    assert_equal "list", @controller.view_assigns["view_mode"]
  end

  test "index with view=grid sets cookie and resolves grid" do
    get workspaces_url(view: "grid")
    assert_response :success
    assert_equal "grid", @controller.view_assigns["view_mode"]
    assert_equal "grid", cookies[:recuerd0_workspace_view]
  end

  test "index resolves view from cookie when no param given" do
    # First request sets the cookie to grid.
    get workspaces_url(view: "grid")
    assert_equal "grid", cookies[:recuerd0_workspace_view]

    # Subsequent request with no view param resolves grid from cookie.
    get workspaces_url
    assert_response :success
    assert_equal "grid", @controller.view_assigns["view_mode"]
  end

  test "index ignores invalid view param" do
    get workspaces_url(view: "bogus")
    assert_response :success
    assert_equal "list", @controller.view_assigns["view_mode"]
  end

  test "index with sort=name orders unpinned workspaces alphabetically" do
    account = accounts(:one)
    account.workspaces.create!(name: "Zebra Workspace")
    account.workspaces.create!(name: "Apple Workspace")

    get workspaces_url(sort: "name")
    assert_response :success
    assert_equal "name", @controller.view_assigns["sort"]

    workspaces = @controller.view_assigns["workspaces"].to_a
    # Pinned workspace(s) first; unpinned tail must be alphabetical.
    pinned = workspaces(:one)
    unpinned_names = workspaces.reject { |w| w == pinned }.map(&:name)
    assert_equal unpinned_names.sort_by(&:downcase), unpinned_names
  end

  test "index sort param defaults to nil for invalid value" do
    get workspaces_url(sort: "bogus")
    assert_response :success
    assert_nil @controller.view_assigns["sort"]
  end

  test "index json returns all active workspaces with pagination headers" do
    account = accounts(:one)
    created = account.workspaces.create!(name: "Extra JSON Workspace")

    get workspaces_url(format: :json)
    assert_response :success

    body = JSON.parse(response.body)
    returned_ids = body.map { |w| w["id"] }

    active_ids = account.workspaces.active.pluck(:id)
    assert_equal active_ids.sort, returned_ids.sort
    assert_includes returned_ids, created.id
    assert response.headers["X-Page"].present?
    assert response.headers["X-Total"].present?
  end

  # -- show --

  test "show responds 200 for active workspace" do
    get workspace_url(@workspace)
    assert_response :success
  end

  test "show renders a copy ID button for an active workspace" do
    get workspace_url(@workspace)

    assert_response :success
    assert_select "[data-controller='clipboard'][data-clipboard-text-value='#{@workspace.id}']" do
      assert_select "button[data-component='button'][data-variant='ghost'][data-size='sm'][data-action='clipboard#copy'][aria-label='Copy workspace ID']", text: /Copy ID/
      assert_select "[data-clipboard-target='copyIcon']", count: 1
      assert_select "[data-clipboard-target='checkIcon'].hidden", count: 1
    end
  end

  test "show defaults memory view to cards" do
    get workspace_url(@workspace)
    assert_response :success
    assert_equal "cards", @controller.view_assigns["memory_view"]
    assert_equal "updated", @controller.view_assigns["memory_sort"]
    assert_select "a.seg-item", text: "Relevance", count: 0
    assert_select "a.seg-item[data-state='on']", text: "Updated"
  end

  test "show with view=compact sets the recuerd0_memory_view cookie" do
    get workspace_url(@workspace, view: "compact")
    assert_response :success
    assert_equal "compact", @controller.view_assigns["memory_view"]
    assert_equal "compact", cookies[:recuerd0_memory_view]
  end

  test "show populates category counts from memories" do
    Memory.create_with_content(@workspace, title: "A decision", content: "b", category: "decision")
    Memory.create_with_content(@workspace, title: "A discovery", content: "b", category: "discovery")

    get workspace_url(@workspace)
    assert_response :success

    counts = @controller.view_assigns["category_counts"]
    assert_equal 1, counts["decision"]
    assert_equal 1, counts["discovery"]
    # general memories come from fixtures (Meeting Notes + Design Doc)
    assert_equal 2, counts["general"]
    # missing category defaults to 0
    assert_equal 0, counts["preference"]
  end

  test "show category counts respect an active search filter" do
    Memory.create_with_content(@workspace, title: "Zebra decision", content: "b", category: "decision")
    @workspace.memories.each(&:rebuild_search_index)

    get workspace_url(@workspace, q: "zzzznotarealterm")
    assert_response :success

    counts = @controller.view_assigns["category_counts"]
    assert_equal 0, counts.values.sum,
      "counts must not advertise matches the filtered list does not contain"
  end

  test "show renders the workspace id so it can be read and hand-selected" do
    get workspace_url(@workspace)
    assert_response :success
    assert_select "code.ws-id", text: @workspace.id.to_s
  end

  test "show prompts for a description when the workspace has none" do
    @workspace.update!(description: nil)

    get workspace_url(@workspace)
    assert_response :success
    assert_select "a[href=?]", edit_workspace_path(@workspace),
      text: I18n.t("workspaces.show.add_description")
  end

  test "show memory groups are headings, not styled spans" do
    get workspace_url(@workspace)
    assert_response :success
    assert_select "h2.ws-group-label", minimum: 1
    assert_select "span.ws-group-label", count: 0
  end

  test "destructive workspace action carries the copy the confirm dialog needs" do
    get workspace_url(@workspace)
    assert_response :success

    # Turbo synthesises a form from a data-turbo-method link and copies only
    # data-turbo-confirm onto it, so the dialog recovers title/button/severity
    # from the trigger. If these attributes go missing the dialog silently
    # degrades to "Confirm / Confirm" on an irreversible action.
    assert_select "a[data-turbo-method=delete][data-confirm-title=?]",
      I18n.t("workspaces.actions.confirm.delete_title", name: @workspace.name)
    assert_select "a[data-turbo-method=delete][data-confirm-button=?]",
      I18n.t("workspaces.actions.confirm.delete_button")
    assert_select "a[data-turbo-method=delete][data-confirm-severity=destructive]"
  end

  test "show filters memories by category" do
    decision = Memory.create_with_content(@workspace, title: "Decided", content: "b", category: "decision")
    Memory.create_with_content(@workspace, title: "Found", content: "b", category: "discovery")

    get workspace_url(@workspace, category: "decision")
    assert_response :success

    memories = @controller.view_assigns["memories"].to_a
    assert_includes memories, decision
    assert(memories.all? { |m| m.category == "decision" })
    assert_equal "decision", @controller.view_assigns["category"]
  end

  test "show filters memories by tag" do
    tagged = Memory.create_with_content(@workspace, title: "Tagged", content: "b", tags: ["onboarding"])
    Memory.create_with_content(@workspace, title: "Other", content: "b", tags: ["billing"])

    get workspace_url(@workspace, tag: "onboarding")
    assert_response :success

    memories = @controller.view_assigns["memories"].to_a
    assert_equal [tagged], memories
    assert_equal "onboarding", @controller.view_assigns["memory_tag"]
  end

  test "show tag filter is case-sensitive" do
    Memory.create_with_content(@workspace, title: "Tagged", content: "b", tags: ["Onboarding"])

    get workspace_url(@workspace, tag: "onboarding")
    assert_response :success

    assert_empty @controller.view_assigns["memories"].to_a
  end

  test "show drops category and query when a tag filter is active" do
    tagged = Memory.create_with_content(@workspace, title: "Tagged decision", content: "b",
      category: "decision", tags: ["onboarding"])
    Memory.create_with_content(@workspace, title: "Other discovery", content: "b",
      category: "discovery", tags: ["onboarding"])

    get workspace_url(@workspace, tag: "onboarding", category: "decision", q: "Tagged decision")
    assert_response :success

    memories = @controller.view_assigns["memories"].to_a
    assert_equal 2, memories.size
    assert_includes memories, tagged
    assert_nil @controller.view_assigns["category"]
    assert_equal "", @controller.view_assigns["memory_query"]
    assert_equal "onboarding", @controller.view_assigns["memory_tag"]
  end

  test "show renders a dismissible active tag chip" do
    Memory.create_with_content(@workspace, title: "Tagged", content: "b", tags: ["onboarding"])

    get workspace_url(@workspace, tag: "onboarding")
    assert_response :success

    # The applied filter is a token, deliberately not a .category-chip: those are
    # toggles, this is state plus a remove action.
    assert_select "a.filter-token .filter-token-value", text: "onboarding"
    assert_select "a.filter-token[aria-label=?]", "Remove tag filter: onboarding"
    assert_select "span.category-chip", count: 0
  end

  test "show renders clickable tag links on memory cards" do
    Memory.create_with_content(@workspace, title: "Tagged", content: "b", tags: ["onboarding"])

    get workspace_url(@workspace)
    assert_response :success

    assert_select "a.tag-badge[aria-label='Filter by tag: onboarding']"
  end

  test "show renders the tag chip even when the tag matches nothing" do
    Memory.create_with_content(@workspace, title: "Untagged", content: "b")

    get workspace_url(@workspace, tag: "nonexistent")
    assert_response :success

    assert_empty @controller.view_assigns["memories"].to_a
    assert_select "a.filter-token .filter-token-value", text: "nonexistent"
    assert_select "a.filter-token[aria-label=?]", "Remove tag filter: nonexistent"
  end

  test "show with sort=title responds 200 and sets memory_sort" do
    get workspace_url(@workspace, sort: "title")
    assert_response :success
    assert_equal "title", @controller.view_assigns["memory_sort"]
    assert_equal "title", @controller.view_assigns["memory_sort_param"]
  end

  test "show invalid sort resolves to updated without a query" do
    get workspace_url(@workspace, sort: "bogus")
    assert_response :success
    assert_equal "updated", @controller.view_assigns["memory_sort"]
    assert_nil @controller.view_assigns["memory_sort_param"]
  end

  test "show filters memories by q query" do
    match = Memory.create_with_content(@workspace, title: "UniqueQueryTermXYZ", content: "b")
    Memory.create_with_content(@workspace, title: "Unrelated", content: "b")

    get workspace_url(@workspace, q: "UniqueQueryTermXYZ")
    assert_response :success

    memories = @controller.view_assigns["memories"].to_a
    assert_includes memories, match
    assert_equal 1, memories.size
    assert_equal "UniqueQueryTermXYZ", @controller.view_assigns["memory_query"]
    assert_equal "relevance", @controller.view_assigns["memory_sort"]
    assert_select "a.seg-item[data-state='on']", text: "Relevance"
  end

  test "show wires the memory filter to the ws-filter accelerators" do
    get workspace_url(@workspace)

    assert_response :success
    assert_select "form.search-field[data-controller='ws-filter'][data-turbo-action='replace']" do
      assert_select "input#memory-toolbar-search[data-ws-filter-target='input']" \
        "[data-action='input->ws-filter#submit search->ws-filter#submit keydown.esc->ws-filter#clear']",
        count: 1
      assert_select "kbd", text: "/", count: 1
    end
  end

  test "show uses relevance and an exact-tag hint for short queries" do
    match = Memory.create_with_content(@workspace, title: "Short tag", content: "body", tags: ["Go"])

    get workspace_url(@workspace, q: "go")

    assert_response :success
    assert_equal [match], @controller.view_assigns["memories"].to_a
    assert_equal "relevance", @controller.view_assigns["memory_sort"]
    assert_select "a.seg-item[data-state='on']", text: "Relevance"
    assert_select "p", text: "Queries under 3 characters search exact tags only."
  end

  test "show omits the short-query hint for longer searches" do
    Memory.create_with_content(@workspace, title: "Long query term", content: "body")

    get workspace_url(@workspace, q: "query")

    assert_response :success
    assert_select "p", text: "Queries under 3 characters search exact tags only.", count: 0
  end

  test "show preserves an explicit sort while editing a query" do
    Memory.create_with_content(@workspace, title: "Sorted search term", content: "body")

    get workspace_url(@workspace, q: "search term", sort: "title")

    assert_response :success
    assert_equal "title", @controller.view_assigns["memory_sort"]
    assert_select "form input[name='sort'][value='title']", count: 1
    assert_select "a.seg-item[data-state='on']", text: "Title"
  end

  test "clearing relevance resolves to updated and hides relevance control" do
    get workspace_url(@workspace, q: " ", sort: "relevance")

    assert_response :success
    assert_equal "", @controller.view_assigns["memory_query"]
    assert_equal "updated", @controller.view_assigns["memory_sort"]
    assert_select "a.seg-item", text: "Relevance", count: 0
    assert_select "a.seg-item[data-state='on']", text: "Updated"
  end

  test "search renders the ranked page as one flat stream with real pin badges" do
    workspace = accounts(:one).workspaces.create!(name: "Flat Search")
    fts = Memory.create_with_content(workspace, title: "Release notes", content: "body")
    pinned_tag = Memory.create_with_content(workspace,
      title: "Pinned tag result", content: "body", tags: ["release notes"])
    pinned_tag.pin!(@user)
    pinned_tag.update_column(:updated_at, 1.hour.from_now)

    get workspace_url(workspace, q: "release notes")

    assert_response :success
    assert_operator response.body.index(fts.title), :<, response.body.index(pinned_tag.title)
    assert_select ".ws-group-label", count: 0
    assert_select ".memory-card .pin-badge[title='Pinned']", count: 1
  end

  test "show redirects to archived path for archived workspace" do
    get workspace_url(@archived_workspace)
    assert_redirected_to archived_workspace_path(@archived_workspace)
  end

  test "show redirects to deleted path for deleted workspace" do
    get workspace_url(@deleted_workspace)
    assert_redirected_to deleted_workspace_path(@deleted_workspace)
  end

  # -- new --

  test "should get new" do
    get new_workspace_url
    assert_response :success
  end

  # -- create --

  test "should create workspace with valid params" do
    assert_difference ["Workspace.count", "Memory.count"], 1 do
      post workspaces_url,
        params: {workspace: {name: "New Workspace", description: "A description"}}
    end

    workspace = Workspace.last
    assert_redirected_to workspace_url(workspace)
    assert_equal I18n.t("workspaces.create.created", name: workspace.name), flash[:notice]

    map = workspace.memories.sole
    assert_equal WorkspaceStarter::TITLE, map.title
    assert map.pinned_by?(@user)

    follow_redirect!
    assert_response :success
    assert_select ".mc-title a", text: WorkspaceStarter::TITLE
    assert_includes response.body, "How this workspace is kept"
  end

  test "should not create workspace without name" do
    assert_no_difference("Workspace.count") do
      post workspaces_url, params: {workspace: {name: "", description: "A description"}}
    end

    assert_response :unprocessable_entity
    assert_equal I18n.t("workspaces.create.errors"), flash[:alert]
  end

  test "should not create workspace with name exceeding max length" do
    assert_no_difference("Workspace.count") do
      post workspaces_url, params: {workspace: {name: "a" * 101}}
    end

    assert_response :unprocessable_entity
  end

  # -- edit --

  test "should get edit" do
    get edit_workspace_url(@workspace)
    assert_response :success
  end

  test "should redirect edit for archived workspace" do
    get edit_workspace_url(@archived_workspace)

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
  end

  test "should redirect edit for deleted workspace" do
    get edit_workspace_url(@deleted_workspace)

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
  end

  # -- update --

  test "should update workspace with valid params" do
    patch workspace_url(@workspace), params: {workspace: {name: "Updated Name"}}

    assert_redirected_to workspace_url(@workspace)
    assert_equal I18n.t("workspaces.update.updated", name: "Updated Name"), flash[:notice]
    assert_equal "Updated Name", @workspace.reload.name
  end

  test "should not update workspace with blank name" do
    patch workspace_url(@workspace), params: {workspace: {name: ""}}

    assert_response :unprocessable_entity
    assert_equal I18n.t("workspaces.update.errors"), flash[:alert]
  end

  test "should redirect update for archived workspace" do
    patch workspace_url(@archived_workspace), params: {workspace: {name: "New Name"}}

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
    assert_equal "Old Project", @archived_workspace.reload.name
  end

  test "should redirect update for deleted workspace" do
    patch workspace_url(@deleted_workspace), params: {workspace: {name: "New Name"}}

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
    assert_equal "Deleted Project", @deleted_workspace.reload.name
  end

  # The JSON body renders pinned/pinned_at outside the record-keyed cache
  # block, so a record-only validator would hand one user another's pin state.
  test "show.json etag varies by viewer" do
    workspace = workspaces(:one)
    assert workspace.pinned_by?(users(:one))
    assert_not workspace.pinned_by?(users(:member))

    sign_in_as(users(:one))
    get workspace_url(workspace, format: :json)
    assert_response :success
    alice_etag = response.headers["ETag"]

    delete session_url
    sign_in_as(users(:member))
    get workspace_url(workspace, format: :json)
    assert_response :success

    assert_not_equal alice_etag, response.headers["ETag"]
  end
end
