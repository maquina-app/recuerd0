require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  BANNER_SELECTOR = "[data-onboarding-banner='true']"
  TITLE = "Get your AI tools reading from this workspace"

  setup do
    @user = Account.create_with_user(
      email_address: "onboarding@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @account = @user.account
    @workspace = @account.workspaces.find_by!(name: "Start Here")

    sign_in_as(@user)
  end

  test "fresh seeded account renders the banner on workspace index and active show" do
    get workspaces_url

    assert_response :success
    assert_fresh_banner

    get workspace_url(@workspace)

    assert_response :success
    assert_fresh_banner
  end

  test "token and CLI progress is account-wide and includes revoked tokens" do
    teammate = @account.users.create!(
      email_address: "onboarding-teammate@example.com",
      password: "password",
      role: "member"
    )
    token = teammate.access_tokens.create!(permission: "full_access")

    get workspaces_url

    assert_select "[data-onboarding-step='1'][data-state='complete'] [data-onboarding-indicator] svg", count: 1
    assert_select "[data-onboarding-step='2'][data-state='incomplete']", count: 1

    token.touch_last_used!

    get workspaces_url

    assert_select "[data-onboarding-step='1'][data-state='complete']", count: 1
    assert_select "[data-onboarding-step='2'][data-state='complete'] [data-onboarding-indicator] svg", count: 1

    token.revoke!

    get workspaces_url

    assert_select "[data-onboarding-step='1'][data-state='complete']", count: 1
    assert_select "[data-onboarding-step='2'][data-state='complete']", count: 1
  end

  test "non-system and null-sourced roots in another account do not affect the banner" do
    other_workspace = accounts(:two).workspaces.create!(name: "Other account content")
    Memory.create_with_content(other_workspace, title: "Manual root", content: "Body", source: "manual")
    null_source = Memory.create_with_content(other_workspace, title: "Null root", content: "Body", source: nil)

    assert_nil null_source.source

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 1
  end

  test "a null-sourced root in another workspace of the same account hides the banner" do
    other_workspace = @account.workspaces.create!(name: "Imported notes")
    root = Memory.create_with_content(other_workspace, title: "Imported root", content: "Body", source: nil)

    assert_nil root.source

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 0
  end

  test "a non-system root in an inactive workspace of the same account hides the banner" do
    archived_workspace = @account.workspaces.create!(name: "Archived import", archived_at: Time.current)
    Memory.create_with_content(
      archived_workspace,
      title: "Archived manual root",
      content: "Body",
      source: "manual"
    )

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 0
  end

  test "editing or versioning a seeded system root does not hide the banner" do
    map = @workspace.memories.find_by!(title: "_MAP")

    map.update_with_content(content: "Edited seeded map")

    assert_equal "system", map.reload.source

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 1

    child_version = map.create_version!(content: "User-authored version", source: "manual")

    assert child_version.persisted?
    assert_equal map, child_version.parent_memory
    assert_equal "manual", child_version.source

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 1
  end

  test "dismissal persists for the current user across reloads and sessions" do
    post onboarding_dismiss_url

    assert_redirected_to workspaces_path
    assert_in_delta Time.current, @user.reload.onboarding_dismissed_at, 1.second

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 0

    fresh_session = open_session
    fresh_session.post session_url,
      params: {email_address: @user.email_address, password: "password"}
    fresh_session.get workspaces_url

    fresh_session.assert_response :success
    fresh_session.assert_select BANNER_SELECTOR, count: 0
  end

  test "dismissal is per-user" do
    teammate = @account.users.create!(
      email_address: "onboarding-dismiss-teammate@example.com",
      password: "password",
      role: "member"
    )

    post onboarding_dismiss_url

    teammate_session = open_session
    teammate_session.post session_url,
      params: {email_address: teammate.email_address, password: "password"}
    teammate_session.get workspaces_url

    teammate_session.assert_response :success
    teammate_session.assert_select BANNER_SELECTOR, count: 1
  end

  test "dismissal requires authentication" do
    anonymous_session = open_session

    anonymous_session.post onboarding_dismiss_url

    anonymous_session.assert_redirected_to new_session_url
    assert_nil @user.reload.onboarding_dismissed_at
  end

  private

  def assert_fresh_banner
    assert_select BANNER_SELECTOR, count: 1 do
      assert_select "[data-card-part='title']", text: TITLE
      assert_select "form[action='#{onboarding_dismiss_path}'] button", text: "Dismiss"
      assert_select "[data-onboarding-step]", count: 4
      assert_select "[data-state='complete']", count: 0
      assert_select "[data-state='incomplete']", count: 3
      assert_select "[data-onboarding-step='1'] .font-medium", text: "1. Create an access token"
      assert_select "[data-onboarding-step='2'] .font-medium", text: "2. Install the CLI and connect"
      assert_select "[data-onboarding-step='3'] .font-medium", text: "3. Import what you already have"
      assert_select "[data-onboarding-step='4'] .font-medium", text: "4. Give your agent the skill"
      assert_select "[data-onboarding-step='4'] [data-onboarding-indicator]", count: 0
      assert_select "[data-onboarding-step='4'][data-state]", count: 0
      assert_select "a[href='#{profile_path(anchor: "access-tokens")}']", text: "Access Tokens"
      assert_select "a[href='#{start_path}']", text: "Full walkthrough"
      assert_select "code", text: "brew install maquina-app/tap/recuerd0"
      assert_select "code", text: "recuerd0 account add"
      assert_select "code", text: "recuerd0 import propose <path>"
      assert_select "code", text: "recuerd0 import commit"
      assert_select "code", text: "recuerd0 skills install"
    end
  end
end
