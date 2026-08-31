require "application_system_test_case"

# The palette's ⌘K badge is written by JavaScript into a <kbd> the server
# renders empty. Filtering submits to the same pathname with turbo_action
# "replace", so Turbo morphs the page — and the morph syncs that <kbd> against
# the empty server markup, blanking it. The controller element survives the
# morph, so connect() never re-runs; only the turbo:morph handler can refill it.
class SearchShortcutHintTest < ApplicationSystemTestCase
  HINT_SELECTOR = "kbd[data-search-command-target='shortcutHint']".freeze

  setup do
    @user = Account.create_with_user(
      email_address: "system-shortcut-hint@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @workspace = @user.account.workspaces.find_by!(name: "My Workspace")
    Memory.create_with_content(@workspace, title: "Infra runbook", content: "body")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    # Land the session before the tests navigate, or the visit races the POST.
    assert_selector "[data-controller=search-command]", visible: :all
  end

  test "the shortcut badge survives filtering workspaces" do
    visit workspaces_path
    assert_shortcut_hint

    fill_in_filter "form.ws-filter input[type=search]", with: "infra"
    assert_shortcut_hint
  end

  test "the shortcut badge survives filtering memories" do
    visit workspace_path(@workspace)
    assert_shortcut_hint

    fill_in_filter "#memory-toolbar-search", with: "infra"
    assert_shortcut_hint
  end

  private

  # The label is platform-derived, so assert on either form rather than on the
  # host the suite happens to run on.
  def assert_shortcut_hint
    assert_selector HINT_SELECTOR, text: /\A(⌘K|Ctrl\+K)\z/, visible: :all
  end

  def fill_in_filter(selector, with:)
    find(selector).fill_in with: with
    # The submit is debounced and morphs the page; wait for it to land.
    assert_current_path(/q=#{with}/, wait: 5)
  end
end
