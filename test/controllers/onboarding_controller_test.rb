require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  BANNER_SELECTOR = "[data-onboarding-banner='true']"

  setup do
    @user = Account.create_with_user(
      email_address: "onboarding@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @account = @user.account
    @workspace = @account.workspaces.find_by!(name: "My Workspace")

    sign_in_as(@user)
  end

  test "fresh seeded account renders a flat banner before workspace page headers" do
    get workspaces_url

    assert_response :success
    assert_fresh_banner
    assert_banner_is_first_content_element
    assert_select "#{BANNER_SELECTOR} ~ div h1", text: "Workspaces"

    get workspace_url(@workspace)

    assert_response :success
    assert_fresh_banner
    assert_banner_is_first_content_element
    assert_select "#{BANNER_SELECTOR} ~ div h1", text: "My Workspace"
  end

  test "a created token completes step one and expands only the CLI step" do
    @user.access_tokens.create!(permission: "full_access")

    get workspaces_url

    assert_response :success
    assert_banner_progress(completed: 1, active_step: 2)
    assert_only_commands(
      "brew install maquina-app/tap/recuerd0",
      "recuerd0 account add"
    )
  end

  test "using a token completes two steps and expands only the import step" do
    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!

    get workspaces_url

    assert_response :success
    assert_banner_progress(completed: 2, active_step: 3)
    assert_only_commands(
      "recuerd0 import propose <path>",
      "recuerd0 import commit"
    )
  end

  test "token and CLI progress is account-wide and includes revoked tokens" do
    teammate = @account.users.create!(
      email_address: "onboarding-teammate@example.com",
      password: "password",
      role: "member"
    )
    token = teammate.access_tokens.create!(permission: "full_access")

    get workspaces_url

    assert_banner_progress(completed: 1, active_step: 2)

    token.touch_last_used!
    token.revoke!

    get workspaces_url

    assert_banner_progress(completed: 2, active_step: 3)
  end

  test "non-system and null-sourced roots in another account do not affect the banner" do
    other_workspace = accounts(:two).workspaces.create!(name: "Other account content")
    Memory.create_with_content(other_workspace, title: "Manual root", content: "Body", source: "manual")
    null_source = Memory.create_with_content(other_workspace, title: "Null root", content: "Body", source: nil)

    assert_nil null_source.source

    get workspaces_url

    assert_select BANNER_SELECTOR, count: 1
  end

  test "a first imported root in another workspace of the same account hides the banner" do
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

  test "inactive workspace show pages do not render the banner" do
    @workspace.update!(archived_at: Time.current)

    get workspace_url(@workspace)

    assert_redirected_to archived_workspace_url(@workspace)
    follow_redirect!

    assert_response :success
    assert_select BANNER_SELECTOR, count: 0
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
    assert_banner_progress(completed: 0, active_step: 1)

    assert_select BANNER_SELECTOR, count: 1 do
      assert_select "p.font-mono", text: "Getting started"
      assert_select "form[action='#{onboarding_dismiss_path}'] button.text-muted-foreground", text: "Dismiss"
      assert_select "[data-onboarding-step]", count: 4
      assert_select "[data-onboarding-indicator]", count: 4
      assert_select "[data-onboarding-step='4'][data-state]", count: 0
      assert_select "[data-onboarding-step='1'] p.font-medium.text-foreground",
        text: "1. Create an access token"
      assert_select "[data-onboarding-step='2'] p.text-muted-foreground",
        text: "2. Install the CLI and connect"
      assert_select "[data-onboarding-step='3'] p.text-muted-foreground",
        text: "3. Import what you already have"
      assert_select "[data-onboarding-step='4'] p.text-muted-foreground",
        text: "4. Give your agent the skill"
      assert_select "a[href='#{profile_path(anchor: "access-tokens")}']", text: "Access Tokens"
      assert_select "a[href='#{start_path}']", text: "Full walkthrough"
      assert_select "code", count: 0
    end

    banner = css_select(BANNER_SELECTOR).first
    assert_equal "section", banner.name
    assert_no_match(/\b(?:bg-|border|rounded|shadow)/, banner["class"].to_s)
    assert_select "#{BANNER_SELECTOR} [data-card-part]", count: 0
  end

  def assert_banner_progress(completed:, active_step:)
    assert_select BANNER_SELECTOR, count: 1 do
      assert_select "p", text: "#{completed}/4 completed"
      assert_select "[data-expanded='true']", count: 1
      assert_select "[data-onboarding-step='#{active_step}'][data-expanded='true']", count: 1
      assert_select "[data-state='complete']", count: completed
      assert_select "[data-state='incomplete']", count: 3 - completed

      (1..completed).each do |step|
        assert_select(
          "[data-onboarding-step='#{step}'][data-state='complete']:not([data-expanded]) " \
            "[data-onboarding-indicator] svg",
          count: 1
        )
      end

      ((completed + 1)..3).each do |step|
        assert_select(
          "[data-onboarding-step='#{step}'][data-state='incomplete'] [data-onboarding-indicator] svg",
          count: 0
        )
      end
    end
  end

  def assert_only_commands(*commands)
    rendered_commands = css_select("#{BANNER_SELECTOR} code").map { |code| code.text.strip }
    assert_equal commands, rendered_commands
  end

  def assert_banner_is_first_content_element
    container = css_select("div.mx-auto.max-w-5xl").first
    first_element = container.element_children.first

    assert_equal "true", first_element["data-onboarding-banner"]
  end
end
