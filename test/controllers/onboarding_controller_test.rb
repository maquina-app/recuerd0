require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  ALERT_SELECTOR = "[data-onboarding-banner='true']"
  DRAWER_SELECTOR = "#onboarding-drawer-provider"
  MENU_TRIGGER_SELECTOR = "[data-onboarding-menu-trigger='true']"

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

  test "fresh account renders a compact alert before both active workspace headers" do
    get workspaces_url

    assert_response :success
    assert_fresh_alert
    assert_select "#{ALERT_SELECTOR} ~ div h1", text: "Workspaces"

    get workspace_url(@workspace)

    assert_response :success
    assert_fresh_alert
    assert_select "#{ALERT_SELECTOR} ~ div h1", text: "My Workspace"
  end

  test "unused and used manual tokens drive only the current user's agent signal" do
    token = @user.access_tokens.create!(permission: "full_access")

    get workspaces_url

    assert_alert_progress(agent: :incomplete, content: :incomplete, completed: 0)

    token.touch_last_used!
    get workspaces_url

    assert_alert_progress(agent: :complete, content: :incomplete, completed: 1)
    assert_menu_label "Getting started · 1 of 2"
  end

  test "a used OAuth token connects the agent" do
    client = OauthClient.create!(
      client_name: "Onboarding request client",
      redirect_uris: ["https://example.com/callback"].to_json
    )
    token = @user.access_tokens.create!(
      permission: "read_only",
      oauth_client: client,
      expires_at: 1.hour.from_now
    )
    token.touch_last_used!

    get workspaces_url

    assert_alert_progress(agent: :complete, content: :incomplete, completed: 1)
  end

  test "account content does not complete the current user's agent signal" do
    Memory.create_with_content(
      @workspace,
      title: "Account content",
      content: "Body",
      source: "manual"
    )
    teammate = @account.users.create!(
      email_address: "onboarding-teammate@example.com",
      password: "password",
      role: "member"
    )

    delete session_url
    post session_url, params: {email_address: teammate.email_address, password: "password"}
    get workspaces_url

    assert_response :success
    assert_alert_progress(agent: :incomplete, content: :complete, completed: 1)
    assert_menu_label "Getting started · 1 of 2"
  end

  test "both completed signals hide only the alert" do
    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!
    Memory.create_with_content(
      @workspace,
      title: "First content",
      content: "Body",
      source: nil
    )

    get workspaces_url

    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
    assert_menu_label "Getting started"
  end

  test "dismissal hides only the alert and persists for the current user" do
    post onboarding_dismiss_url

    assert_response :see_other
    assert_redirected_to workspaces_path
    assert_in_delta Time.current, @user.reload.onboarding_dismissed_at, 1.second

    get workspaces_url

    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
    assert_menu_label "Getting started · 0 of 2"
  end

  test "drawer and menu trigger are global on signed-in non-workspace pages" do
    get profile_url

    assert_response :success
    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
    assert_menu_label "Getting started · 0 of 2"
  end

  test "logged-out application pages do not mount onboarding controls" do
    delete session_url
    get new_session_url

    assert_response :success
    assert_select DRAWER_SELECTOR, count: 0
    assert_select MENU_TRIGGER_SELECTOR, count: 0
  end

  test "inactive workspace pages do not render the alert" do
    @workspace.update!(archived_at: Time.current)

    get workspace_url(@workspace)

    assert_redirected_to archived_workspace_url(@workspace)
    follow_redirect!

    assert_response :success
    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
  end

  test "drawer contains exact Terminal commands and complete Chat guidance" do
    get workspaces_url

    assert_global_drawer
    assert_select "#onboarding-connection-methods[data-component='toggle-group'][data-variant='outline']" do
      assert_select "[data-value='terminal'][data-state='on'][aria-pressed='true']", text: "Terminal"
      assert_select "[data-value='chat'][data-state='off'][aria-pressed='false']", text: "Chat"
    end

    commands = css_select("[data-onboarding-panel='terminal'] [data-onboarding-command] code")
      .map { |command| command.text.strip }
    assert_equal [
      "brew install maquina-app/tap/recuerd0",
      "recuerd0 account add personal --token <token>",
      "recuerd0 workspace list",
      "recuerd0 import propose <path> --workspace <id>",
      "recuerd0 import commit import.plan.yaml",
      "recuerd0 skills install"
    ], commands
    assert_not_includes commands, "recuerd0 import commit import.plan.yaml --yes"
    assert_select "[data-onboarding-command][data-controller='clipboard']", count: 6
    assert_select "[data-onboarding-command] button[data-action='clipboard#copy']", count: 6
    assert_select "[data-onboarding-command] code[data-clipboard-target='source']", count: 6
    assert_select "[data-onboarding-panel='terminal'] a[href='#{profile_path(anchor: "access-tokens")}']",
      text: "Access Tokens"

    assert_select "[data-onboarding-panel='chat'][hidden]" do
      assert_select "a[href='https://recuerd0.ai/mcp']", text: "https://recuerd0.ai/mcp"
      assert_select "a[href='#{recuerd0_mcp_skill_path}']", text: "Download the recuerd0 MCP skill"
      assert_select "p", text: /Sign in in the browser/
      assert_select "p", text: /do not need to create or paste an access token/
      assert_select "p", text: /create your first memory/
      assert_select "p", text: "Folder imports require Terminal because they read local files."
    end

    assert_select "[data-drawer-part='footer'] a[href='#{start_path}']", text: "Full walkthrough"
    assert_select "[data-drawer-part='footer'] p", text: /Reopen this drawer anytime from the user menu/
  end

  private

  def assert_fresh_alert
    assert_select "#{ALERT_SELECTOR}[data-component='alert'][data-variant='default'][data-has-icon='true']", count: 1 do
      assert_select "[data-onboarding-alert-row]", count: 1
      assert_select "ol", count: 0
      assert_select "p", text: "Finish setting up — connect an agent so it can read and write here."
      assert_select "button", text: "Show me how"
      assert_select "form[action='#{onboarding_dismiss_path}'] button", text: "Dismiss"
    end
    assert_alert_progress(agent: :incomplete, content: :incomplete, completed: 0)
    assert_global_drawer
    assert_menu_label "Getting started · 0 of 2"
  end

  def assert_alert_progress(agent:, content:, completed:)
    assert_select ALERT_SELECTOR, count: 1 do
      assert_select "[data-onboarding-progress][aria-label='#{completed} of 2 setup steps complete']"
      assert_select "[data-onboarding-pip='agent'][data-state='#{agent}']", count: 1
      assert_select "[data-onboarding-pip='content'][data-state='#{content}']", count: 1
      assert_select "[data-onboarding-pip].bg-primary", count: completed
      assert_select "[data-onboarding-pip].bg-border", count: 2 - completed
    end
  end

  def assert_global_drawer
    assert_select DRAWER_SELECTOR, count: 1 do
      assert_select "[data-controller~='drawer'][data-controller~='onboarding-drawer']", count: 1
      assert_select "[data-drawer-cookie-name-value='recuerd0_onboarding_drawer_state']"
      assert_select "#onboarding-drawer[data-drawer-part='root'][data-state='closed'][data-side='right']"
      assert_select "#onboarding-drawer-panel[role='dialog'][aria-label='Connect your agent'][aria-hidden='true'][inert]"
    end
  end

  def assert_menu_label(text)
    assert_select MENU_TRIGGER_SELECTOR, count: 1 do
      assert_select "[data-controller~='drawer-trigger']"
      assert_select "[data-action~='click->drawer-trigger#triggerClick']"
      assert_select "*", text: /#{Regexp.escape(text)}/
    end
  end
end
