require "test_helper"

class Memories::PinnedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "index renders pinned memories" do
    sign_in_as(@user)
    get pinned_memories_url
    assert_response :success
    assert_select "h1", text: I18n.t("memories.pinned.index.title")
    assert_select "li .memory-card", count: 1
  end

  test "index shows empty state when no pinned memories" do
    sign_in_as(users(:two))
    get pinned_memories_url
    assert_response :success
    assert_select "[data-component='empty']"
  end

  test "index requires authentication" do
    get pinned_memories_url
    assert_redirected_to new_session_url
  end

  # The page carried a single heading and ten anonymous divs, so a screen
  # reader had no structure to skim a list whose whole point is that items come
  # from different workspaces.
  test "index groups memories under a labelled section per workspace" do
    sign_in_as(@user)
    get pinned_memories_url

    workspace = memories(:one).workspace
    assert_select "section[aria-labelledby=?]", "pinned-ws-#{workspace.id}"
    assert_select "h2#pinned-ws-#{workspace.id}", text: /#{Regexp.escape(workspace.name)}/
    assert_select "ul li .memory-card"
  end

  # The explainer was a components/alert, which renders role="alert" — an
  # assertive live region interrupting on every visit with a permanent,
  # purely informational paragraph.
  test "index does not announce a static banner as an alert" do
    sign_in_as(@user)
    get pinned_memories_url
    assert_select "[role='alert']", count: 0
  end

  test "index surfaces the pin budget" do
    sign_in_as(@user)
    get pinned_memories_url
    assert_select "p", text: /#{Regexp.escape(I18n.t("memories.pinned.index.budget", used: @user.pinned_items_count, limit: User::PIN_LIMIT))}/
  end

  test "index filters to a single workspace" do
    sign_in_as(@user)
    workspace = memories(:one).workspace

    get pinned_memories_url(workspace_id: workspace.id)
    assert_response :success
    assert_select "section[aria-labelledby=?]", "pinned-ws-#{workspace.id}"
    assert_select "li .memory-card", count: 1
  end

  test "index shows a filtered empty state for a workspace with no pins" do
    sign_in_as(@user)
    empty = @user.account.workspaces.where.not(id: memories(:one).workspace_id).first
    skip "fixtures have only one workspace for this account" if empty.nil?

    get pinned_memories_url(workspace_id: empty.id)
    assert_response :success
    assert_select "[data-component='empty']"
  end

  test "index renders the compact view when asked" do
    sign_in_as(@user)
    get pinned_memories_url(view: "compact")
    assert_response :success
    assert_select "li .memory-row"
    assert_select "li .memory-card", count: 0
  end

  test "index accepts a title sort without error" do
    sign_in_as(@user)
    get pinned_memories_url(sort: "title")
    assert_response :success
  end

  # Pins belong to a user, not an account, so the JSON has to answer for the
  # token's user — and the pinned set had no JSON representation at all.
  test "index responds to json with the token user's pinned memories" do
    memory = memories(:one)
    get pinned_memories_url(format: :json), headers: auth_headers("test_read_token_123")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [memory.id], body.map { |m| m["id"] }
    assert body.first["pinned"]
    assert body.first["pinned_at"].present?
  end

  test "json pinned set is scoped to the user, not the account" do
    other = users(:member)
    assert_equal @user.account_id, other.account_id, "fixture precondition: same account"
    assert_empty other.pinned_memories, "fixture precondition: other user has no pins"

    sign_in_as(other)
    get pinned_memories_url(format: :json)

    assert_response :success
    assert_empty JSON.parse(response.body)
  end

  # PIN_LIMIT caps a user at ten pins across workspaces and memories combined,
  # so the old `items: 10` pager could never reach a second page.
  test "index renders no pagination control" do
    sign_in_as(@user)
    get pinned_memories_url
    assert_select "[data-component='pagination']", count: 0
  end
end
