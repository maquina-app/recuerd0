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
    assert_select ".grid .group", count: 1
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
end
