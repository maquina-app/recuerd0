require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Fixtures bypass ActiveRecord callbacks, so FTS5 index is empty.
    # Rebuild only the memories used in these tests.
    [memories(:one), memories(:two), memories(:versioned_parent)].each(&:rebuild_search_index)
  end

  test "index requires authentication" do
    get search_url
    assert_redirected_to new_session_url
  end

  test "index renders search page with no query" do
    sign_in_as(@user)
    get search_url
    assert_response :success
    assert_select "h1", text: I18n.t("search.index.title")
    assert_select "[data-component='empty']"
  end

  test "index returns results for matching query" do
    sign_in_as(@user)
    get search_url, params: {q: "Meeting"}
    assert_response :success
    assert_select ".grid .group", minimum: 1
  end

  test "index shows empty state for unmatched query" do
    sign_in_as(@user)
    get search_url, params: {q: "xyznonexistent"}
    assert_response :success
    assert_select "[data-component='empty']"
  end

  test "index shows warning for short query" do
    sign_in_as(@user)
    get search_url, params: {q: "ab"}
    assert_response :success
    assert_select "[data-component='alert']"
  end

  test "user cannot see other users memories" do
    sign_in_as(@user)
    get search_url, params: {q: "Shopping"}
    assert_response :success
    assert_select ".grid .group", count: 0
  end

  test "search bar is present in header" do
    sign_in_as(@user)
    get workspaces_url
    assert_response :success
    assert_select "input[type='search']"
  end

  test "query is HTML-escaped in results" do
    sign_in_as(@user)
    xss_query = "<script>alert(1)</script>"
    get search_url, params: {q: xss_query}
    assert_response :success
    assert_no_match "<script>alert(1)</script>", response.body
  end

  test "global search cards show a pin badge only for a genuinely pinned memory" do
    sign_in_as(@user)
    memory = Memory.create_with_content(workspaces(:one),
      title: "Unique unpinned global result", content: "body")

    get search_url, params: {q: "Unique unpinned"}
    assert_response :success
    assert_select ".memory-card .inline-flex.text-primary[title='Pinned']", count: 0

    memory.pin!(@user)
    get search_url, params: {q: "Unique unpinned"}
    assert_response :success
    assert_select ".memory-card .inline-flex.text-primary[title='Pinned']", count: 1
  end

  test "global search keeps FTS rank ahead of recency" do
    sign_in_as(@user)
    workspace = accounts(:one).workspaces.create!(name: "Global Rank")
    stronger = Memory.create_with_content(workspace,
      title: "Global rank",
      content: (["globalrankneedle"] * 20).join(" "))
    weaker = Memory.create_with_content(workspace,
      title: "Newer global rank", content: "globalrankneedle")
    stronger.update_column(:updated_at, 2.days.ago)
    weaker.update_column(:updated_at, 1.hour.from_now)

    get search_url, params: {q: "globalrankneedle"}

    assert_response :success
    assert_operator response.body.index(stronger.title), :<, response.body.index(weaker.title)
  end
end
