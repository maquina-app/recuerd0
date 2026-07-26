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

    assert_select "span.category-chip", text: /Tag: onboarding/
    assert_select "a[aria-label='Clear tag filter']"
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
    assert_select "span.category-chip", text: /Tag: nonexistent/
    assert_select "a[aria-label='Clear tag filter']"
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
    assert_select ".memory-card .inline-flex.text-primary[title='Pinned']", count: 1
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
    assert_difference("Workspace.count") do
      post workspaces_url, params: {workspace: {name: "New Workspace", description: "A description"}}
    end

    assert_redirected_to workspace_url(Workspace.last)
    assert_equal I18n.t("workspaces.create.created"), flash[:notice]
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
    assert_equal I18n.t("workspaces.update.updated"), flash[:notice]
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
end
