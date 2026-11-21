require "test_helper"

# The recuerd0_preferences cookie (ListPreferences): one browser-only JSON
# cookie remembering the Workspaces, Memories and Pinned list controls.
class ListPreferencesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    sign_in_as(@user)
  end

  # -- Workspaces --

  test "workspace sort, query, view and mine are restored on a bare visit" do
    get workspaces_url(sort: "name", q: "  Proj  ", view: "grid", mine: "1")

    assert_equal({"sort" => "name", "q" => "Proj", "view" => "grid", "mine" => true}, preferences["workspaces"])

    get workspaces_url
    assert_equal "name", @controller.view_assigns["sort"]
    assert_equal "Proj", @controller.view_assigns["query"]
    assert_equal "grid", @controller.view_assigns["view_mode"]
    assert @controller.view_assigns["mine"]
    assert_select ".seg[aria-label=Show] a[data-state=on]", text: "Mine"
    assert_select "input[name=q][value=Proj]"
  end

  test "changing one workspace preference keeps the others" do
    get workspaces_url(sort: "memories", view: "grid")
    get workspaces_url(q: "notes")

    assert_equal({"sort" => "memories", "view" => "grid", "q" => "notes"}, preferences["workspaces"])
  end

  test "a blank param clears the remembered value and an invalid one is ignored" do
    get workspaces_url(sort: "name", view: "grid", q: "notes")

    get workspaces_url(sort: "bogus", view: "table")
    assert_equal "name", @controller.view_assigns["sort"]
    assert_equal "grid", @controller.view_assigns["view_mode"]

    get workspaces_url(sort: "", q: "")
    assert_nil @controller.view_assigns["sort"]
    assert_nil @controller.view_assigns["query"]
    assert_equal({"view" => "grid"}, preferences["workspaces"])
  end

  test "the workspace query is capped at 80 characters" do
    get workspaces_url(q: "x" * 120)

    assert_equal 80, preferences.dig("workspaces", "q").length
  end

  test "archived and deleted lists share the workspace view and query" do
    get workspaces_url(view: "grid", q: "Arch")

    get archived_workspaces_url
    assert_equal "grid", @controller.view_assigns["view_mode"]
    assert_equal "Arch", @controller.view_assigns["query"]

    get deleted_workspaces_url(q: "")
    assert_nil @controller.view_assigns["query"]
    assert_nil preferences.dig("workspaces", "q")
  end

  test "the old per-page view cookies seed the unified cookie" do
    cookies[:recuerd0_workspace_view] = "grid"
    cookies[:recuerd0_memory_view] = "compact"

    get workspaces_url
    assert_equal "grid", @controller.view_assigns["view_mode"]
    get workspace_url(@workspace)
    assert_equal "compact", @controller.view_assigns["memory_view"]

    # The unified value wins once it exists.
    get workspaces_url(view: "list")
    get workspaces_url
    assert_equal "list", @controller.view_assigns["view_mode"]
  end

  test "a malformed or misshaped cookie reads as nothing saved" do
    ['{"workspaces":', "[1,2]", '{"workspaces":"grid"}', '{"workspaces":{"view":["grid"],"sort":7,"mine":"yes"}}'].each do |raw|
      cookies[:recuerd0_preferences] = Rack::Utils.escape(raw)

      get workspaces_url
      assert_response :success
      assert_equal "list", @controller.view_assigns["view_mode"]
      assert_nil @controller.view_assigns["sort"]
      assert_not @controller.view_assigns["mine"]
    end
  end

  test "the cookie is HttpOnly, SameSite=Lax, lasts a year and holds no identity" do
    get workspaces_url(view: "grid", mine: "1")

    header = Array(response.headers["Set-Cookie"]).join("\n").lines.find { it.start_with?("recuerd0_preferences=") }
    assert_match(/httponly/i, header)
    assert_match(/samesite=lax/i, header)
    assert_match(/expires=/i, header)

    raw = cookies[:recuerd0_preferences]
    [@user.id, @user.email_address, @user.account_id].each { assert_no_match(/\b#{Regexp.escape(it.to_s)}\b/, raw) }
  end

  test "JSON and Bearer-token requests neither read nor write preferences" do
    get workspaces_url(sort: "name")

    get workspaces_url(format: :json)
    assert_nil @controller.view_assigns["sort"]
    get workspaces_url(format: :json, sort: "memories")
    assert_equal "name", preferences.dig("workspaces", "sort")

    delete session_url
    get workspaces_url(sort: "memories"), headers: auth_headers("test_full_token_456")
    assert_response :success
    assert_nil response.headers["Set-Cookie"].to_s[/recuerd0_preferences=[^;]+/]
  end

  # -- Memories inside a workspace --

  test "memory filters are remembered across workspaces, not per workspace" do
    get workspace_url(@workspace, category: "decision", q: " design ", sort: "title", view: "compact")
    assert_equal({"category" => "decision", "q" => "design", "sort" => "title", "view" => "compact"}, preferences["memories"])

    get archived_workspace_url(workspaces(:archived))
    assert_equal "decision", @controller.view_assigns["category"]
    assert_equal "design", @controller.view_assigns["memory_query"]
    assert_equal "title", @controller.view_assigns["memory_sort"]
    assert_equal "compact", @controller.view_assigns["memory_view"]
  end

  test "search keeps relevance as its default sort when no sort is remembered" do
    get workspace_url(@workspace, q: "design")
    get workspace_url(@workspace)

    assert_equal "relevance", @controller.view_assigns["memory_sort"]
  end

  test "a tag replaces the remembered category and search, and clearing it brings neither back" do
    get workspace_url(@workspace, category: "decision", q: "design", sort: "title")
    get workspace_url(@workspace, tag: "architecture")
    assert_equal({"sort" => "title", "tag" => "architecture"}, preferences["memories"])

    get workspace_url(@workspace)
    assert_equal "architecture", @controller.view_assigns["memory_tag"]
    assert_nil @controller.view_assigns["category"]
    assert_select "a.filter-token[href=?]", workspace_path(@workspace, sort: "title", view: "cards", tag: "")
    assert_select "form.search-field input[type=hidden][name=tag][value='']"

    get workspace_url(@workspace, tag: "")
    assert_nil @controller.view_assigns["memory_tag"]
    assert_equal({"sort" => "title"}, preferences["memories"])
  end

  test "the All chip clears category and tag explicitly" do
    get workspace_url(@workspace, category: "decision")

    assert_select ".category-bar a.category-chip[href=?]", workspace_path(@workspace, view: "cards", category: "", tag: "")
  end

  # -- Pinned --

  test "pinned workspace, sort and view are remembered and cleared by All" do
    get pinned_memories_url(workspace_id: @workspace.id, sort: "title", view: "compact")
    assert_equal({"workspace_id" => @workspace.id, "sort" => "title", "view" => "compact"}, preferences["pinned"])

    get pinned_memories_url
    assert_equal @workspace, @controller.view_assigns["workspace_filter"]
    assert_equal "title", @controller.view_assigns["sort"]
    assert_equal "compact", @controller.view_assigns["view"]

    get pinned_memories_url(workspace_id: "")
    assert_nil @controller.view_assigns["workspace_filter"]
    assert_equal({"sort" => "title", "view" => "compact"}, preferences["pinned"])
  end

  test "a pinned workspace outside the account is never stored or applied" do
    get pinned_memories_url(workspace_id: workspaces(:two).id)
    assert_nil @controller.view_assigns["workspace_filter"]
    assert_nil preferences["pinned"]

    cookies[:recuerd0_preferences] = Rack::Utils.escape({pinned: {workspace_id: workspaces(:two).id}}.to_json)
    get pinned_memories_url
    assert_nil @controller.view_assigns["workspace_filter"]
  end

  private

  def preferences
    JSON.parse(cookies[:recuerd0_preferences].to_s)
  rescue JSON::ParserError
    {}
  end
end
