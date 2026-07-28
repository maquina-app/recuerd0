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
    assert_alert_message(
      title: "Almost there",
      text: "Almost there — ask your agent to save its first memory."
    )
    assert_menu_label "Finish setting up"
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
    assert_menu_label "Finish setting up"
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
    assert_menu_label "Finish setting up"
  end

  test "dismissal hides only the alert and persists for the current user" do
    post onboarding_dismiss_url

    assert_response :see_other
    assert_redirected_to workspaces_path
    assert_in_delta Time.current, @user.reload.onboarding_dismissed_at, 1.second

    get workspaces_url

    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
    assert_menu_label "Finish setting up"
  end

  test "drawer and menu trigger are global on signed-in non-workspace pages" do
    get profile_url

    assert_response :success
    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
    assert_menu_label "Finish setting up"
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
    assert_select "#onboarding-connection-methods[data-component='toggle-group'][data-variant='default']" do
      assert_select "[data-value='terminal'][data-state='on'][aria-pressed='true']", text: "Terminal"
      assert_select "[data-value='chat'][data-state='off'][aria-pressed='false']", text: "Chat"
    end

    commands = css_select("[data-onboarding-panel='terminal'] [data-onboarding-command] code")
      .map { |command| command.text.strip }
    assert_equal [
      "brew install maquina-app/tap/recuerd0",
      "recuerd0 account add personal --token <token>",
      "recuerd0 skills install",
      "recuerd0 workspace list",
      "recuerd0 import propose <path> --workspace <id>",
      "recuerd0 import commit import.plan.yaml"
    ], commands
    assert_not_includes commands, "recuerd0 import commit import.plan.yaml --yes"
    assert_select "[data-onboarding-command][data-controller='clipboard']", count: 7
    assert_select "[data-onboarding-command] button[data-action='clipboard#copy']", count: 7
    assert_select "[data-onboarding-command] code[data-clipboard-target='source']", count: 7
    assert_select "[data-onboarding-panel='terminal'] [data-onboarding-item][data-onboarding-step='1']" do
      assert_select "p", text: "Create a full-access token in Access Tokens first." do
        assert_select "a[href='#{profile_path(anchor: "access-tokens")}'].text-primary",
          text: "Access Tokens"
      end
      assert_select "a[data-component='button']", text: "Create access token", count: 0
    end
    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Propose, read the plan, then commit.",
      count: 1
    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Teaches your agent how to read, write and search here.",
      count: 1
    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Ask your agent to save something here.",
      count: 1

    assert_select "[data-onboarding-panel='chat'][hidden]" do
      assert_select "[data-onboarding-command] code", text: "https://recuerd0.ai/mcp"
      assert_select "a[href='#{recuerd0_mcp_skill_path}'][data-component='button'][data-variant='outline']",
        text: "Download skill"
      assert_select "p", text: "Browser sign-in — no token to copy."
      assert_select "p", text: "Teaches your agent how to read, write and search here."
      assert_select "p", text: "Ask your agent to save something here."
      assert_select "p",
        text: "Importing a folder of notes needs the Terminal — it reads files from your machine.",
        count: 0
    end

    {
      "terminal" => 2,
      "chat" => 1
    }.each do |panel, guidance_count|
      assert_select "[data-onboarding-panel='#{panel}']" do
        assert_select "[data-onboarding-item][data-onboarding-kind='tracked']", count: 2
        assert_select "[data-onboarding-marker='number']", count: 2
        assert_select "[data-onboarding-marker='guidance']", text: "•", count: guidance_count
      end
    end

    guidance_markers = css_select("[data-onboarding-marker='guidance']")
    assert_equal 3, guidance_markers.size
    guidance_markers.each do |marker|
      assert_includes marker["class"], "text-[#C9C9C6]"
      assert_not_includes marker["class"], "rounded-full"
      assert_not_includes marker["class"].split, "border"
    end

    assert_select "[data-onboarding-optional][data-component='badge'][data-variant='outline']",
      text: "optional",
      count: 1
    assert_select "[data-drawer-part='header']" do
      assert_select "p", text: "Getting started", count: 1
      assert_select "h2", text: "Connect your agent", count: 1
      assert_select "a[href='#{start_path}']", text: "Full walkthrough", count: 1
      assert_select "[data-onboarding-subtitle]", count: 0
    end
    assert_select "[data-onboarding-footnote]", count: 0
    assert_select "[data-drawer-part='footer']", count: 0
    assert_select "p", text: "Choose the path that matches how your agent works.", count: 0
    assert_select "p", text: "Everything you need, kept here for reference.", count: 0
    assert_select "p", text: /Progress reflects what the server can see/, count: 0
    assert_select "p", text: "Reopen anytime from the user menu.", count: 0
  end

  private

  def assert_fresh_alert
    assert_select "#{ALERT_SELECTOR}[data-component='alert'][data-variant='default'][data-has-icon='true']", count: 1 do
      assert_includes css_select(ALERT_SELECTOR).first["class"].split, "mb-8"
      assert_select "[data-onboarding-alert-row]", count: 1
      assert_select "ol", count: 0
      assert_select "button[data-component='button'][data-variant='outline'][data-size='sm']",
        text: "Show me how"
      assert_select "form[action='#{onboarding_dismiss_path}'] button[data-component='button'][data-variant='ghost'][data-size='sm']",
        text: "Dismiss"
      assert_select "[data-component='separator'][data-orientation='vertical']", count: 1
    end
    assert_alert_message(
      title: "Finish setting up",
      text: "Finish setting up — connect an agent so it can read and write here."
    )
    assert_alert_progress(agent: :incomplete, content: :incomplete, completed: 0)
    assert_global_drawer
    assert_menu_label "Finish setting up"
  end

  def assert_alert_progress(agent:, content:, completed:)
    assert_select ALERT_SELECTOR, count: 1 do
      assert_select "[data-onboarding-progress][aria-label='#{completed} of 2 setup steps complete']"
      assert_select "[data-onboarding-pip='agent'][data-state='#{agent}']", count: 1
      assert_select "[data-onboarding-pip='content'][data-state='#{content}']", count: 1
      assert_select "[data-onboarding-pip].bg-primary", count: completed
      assert_select "[data-onboarding-pip].bg-border", count: 2 - completed
      assert_select "[data-onboarding-pip].h-1.w-\\[22px\\]", count: 2
      assert_select "span", text: /\A#{completed} of 2\z/, count: 1
    end
  end

  def assert_alert_message(title:, text:)
    assert_select ALERT_SELECTOR, count: 1 do
      assert_select "p", text: text, count: 1 do
        assert_select "strong", text: title, count: 1
      end
    end
  end

  def assert_global_drawer
    assert_select DRAWER_SELECTOR, count: 1 do
      assert_select "[data-controller~='drawer'][data-controller~='onboarding-drawer']", count: 1
      assert_select "[data-drawer-cookie-name-value='recuerd0_onboarding_drawer_state']"
      assert_select "[data-drawer-cookie-max-age-value='0']"
      assert_select "#onboarding-drawer[data-drawer-part='root'][data-state='closed'][data-side='right']", count: 1 do |drawers|
        assert_includes drawers.first["class"], "[&_[data-drawer-part=backdrop]]:!fixed"
        assert_includes drawers.first["class"], "[&_[data-drawer-part=backdrop]]:!z-[60]"
        assert_includes drawers.first["class"], "[&_[data-drawer-part=panel]]:!z-[70]"
        assert_includes drawers.first["class"], "[&_[data-drawer-part=panel]]:!w-[480px]"
      end
      assert_select "#onboarding-drawer-panel[role='dialog'][aria-label='Connect your agent'][aria-hidden='true'][inert]"
    end
  end

  def assert_menu_label(text)
    assert_select MENU_TRIGGER_SELECTOR, count: 1 do
      assert_select "[data-controller~='drawer-trigger']"
      assert_select "[data-action~='click->drawer-trigger#triggerClick']"
      trigger = css_select(MENU_TRIGGER_SELECTOR).first
      assert_equal text, trigger.text.squish
    end
  end
end
