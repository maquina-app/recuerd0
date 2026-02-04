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
    assert_no_match "<script>", response.body
  end
end
