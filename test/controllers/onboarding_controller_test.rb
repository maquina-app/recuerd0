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

  test "unused tokens do not connect either path and a used manual token connects only Terminal" do
    manual_token = @user.access_tokens.create!(permission: "full_access")
    create_oauth_token

    get workspaces_url

    assert_onboarding_state(terminal: :incomplete, chat: :incomplete, content: :incomplete)

    manual_token.touch_last_used!
    get workspaces_url

    assert_onboarding_state(terminal: :complete, chat: :incomplete, content: :incomplete)
  end

  test "a used OAuth token connects only Chat" do
    token = create_oauth_token
    token.touch_last_used!

    get workspaces_url

    assert_onboarding_state(terminal: :incomplete, chat: :complete, content: :incomplete)
  end

  test "used manual and OAuth tokens connect both drawer paths" do
    manual_token = @user.access_tokens.create!(permission: "full_access")
    oauth_token = create_oauth_token
    manual_token.touch_last_used!
    oauth_token.touch_last_used!

    get workspaces_url

    assert_onboarding_state(terminal: :complete, chat: :complete, content: :incomplete)
  end

  test "teammate account content folds both content steps but does not connect either path" do
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
    assert_onboarding_state(terminal: :incomplete, chat: :incomplete, content: :complete)
  end

  test "manual connection and content complete onboarding while Chat stays expanded" do
    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!
    Memory.create_with_content(
      @workspace,
      title: "First content",
      content: "Body",
      source: nil
    )

    get workspaces_url

    assert_onboarding_state(terminal: :complete, chat: :incomplete, content: :complete)
  end

  test "both connection types and content fold all eight drawer items" do
    manual_token = @user.access_tokens.create!(permission: "full_access")
    oauth_token = create_oauth_token
    manual_token.touch_last_used!
    oauth_token.touch_last_used!
    Memory.create_with_content(
      @workspace,
      title: "First content",
      content: "Body",
      source: nil
    )

    get workspaces_url

    assert_onboarding_state(terminal: :complete, chat: :complete, content: :complete)
  end

  test "dismissal hides only the alert and persists for the current user" do
    post onboarding_dismiss_url

    assert_response :see_other
    assert_redirected_to workspaces_path
    assert_in_delta Time.current, @user.reload.onboarding_dismissed_at, 1.second

    get workspaces_url

    assert_select ALERT_SELECTOR, count: 0
    assert_global_drawer
    assert_drawer_state(terminal: :incomplete, chat: :incomplete, content: :incomplete)
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
      "recuerd0 workspace list",
      "recuerd0 skills install",
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
      assert_select "[data-onboarding-command] code", text: "recuerd0 workspace list", count: 1
      assert_select "p", text: "Confirms the connection.", count: 1
    end
    terminal_connect_body = css_select("#onboarding-terminal-connect-body").first
    terminal_connect_commands = terminal_connect_body
      .css("[data-onboarding-command] code")
      .map { |command| command.text.strip }
    assert_equal [
      "brew install maquina-app/tap/recuerd0",
      "recuerd0 account add personal --token <token>",
      "recuerd0 workspace list"
    ], terminal_connect_commands
    assert_equal "Confirms the connection.", terminal_connect_body.element_children[-2].text.squish
    assert_equal "recuerd0 workspace list",
      terminal_connect_body.element_children[-1].at_css("code").text.strip

    terminal_import_body = css_select("#onboarding-terminal-import-body").first
    terminal_import_commands = terminal_import_body
      .css("[data-onboarding-command] code")
      .map { |command| command.text.strip }
    assert_equal [
      "recuerd0 import propose <path> --workspace <id>",
      "recuerd0 import commit import.plan.yaml"
    ], terminal_import_commands
    assert_not_includes terminal_import_body.text, "recuerd0 workspace list"

    terminal_items = css_select("[data-onboarding-panel='terminal'] > [data-onboarding-item]")
    terminal_titles = terminal_items.map do |item|
      item.at_css("[data-onboarding-item-title]").text.squish
    end
    assert_equal [
      "Install and connect",
      "Give your agent the skill",
      "Import existing notes",
      "Have your agent organise the import",
      "Add your first memory"
    ], terminal_titles
    organise_item = terminal_items[3]
    assert_equal "guidance", organise_item["data-onboarding-kind"]
    assert_equal "•", organise_item.at_css("[data-onboarding-marker='guidance']").text.squish
    assert_equal(
      'Ask your agent: "I just imported notes into recuerd0 workspace <id>. Do the after-import pass." ' \
        "It will cluster the memories, fix weak titles, and propose hubs for review.",
      organise_item.at_css("[data-onboarding-item-body] p").text.squish
    )
    assert_empty organise_item.css("[data-onboarding-optional]")
    assert_empty organise_item.css("[data-onboarding-command]")

    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Propose, read the plan, then commit.",
      count: 1
    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Propose writes import.plan.yaml in your current directory. Open it — the manifest lists one entry per file with the title, category and tags it will use.",
      count: 1
    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Teaches your agent how to read, write and search here. Claude Code loads it automatically. Other agents need the file added manually.",
      count: 1
    assert_select "[data-onboarding-panel='terminal'] p",
      text: "Ask your agent to save something here.",
      count: 1

    assert_select "[data-onboarding-panel='chat'][hidden]" do
      assert_select "[data-onboarding-command] code", text: "https://recuerd0.ai/mcp"
      assert_select "a[href='#{recuerd0_mcp_skill_path}'][data-component='button'][data-variant='outline']",
        text: "Download skill"
      assert_select "p",
        text: "In Claude Desktop or Claude.ai, open Settings → Connectors and add a custom connector with this URL. Browser sign-in — no token to copy."
      assert_select "p", text: "Teaches your agent how to read, write and search here."
      assert_select "p",
        text: "Save the file, then add it to your client's skills — in Claude.ai, open your project's settings and upload it there."
      assert_select "p", text: "Ask your agent to save something here."
      assert_select "[data-onboarding-item-title]", text: "Have your agent organise the import", count: 0
      assert_select "p",
        text: "Importing a folder of notes needs the Terminal — it reads files from your machine.",
        count: 0
    end

    {
      "terminal" => 3,
      "chat" => 1
    }.each do |panel, guidance_count|
      assert_select "[data-onboarding-panel='#{panel}']" do
        assert_select "[data-onboarding-item][data-onboarding-kind='tracked']", count: 2
        assert_select "[data-onboarding-marker='number']", count: 2
        assert_select "[data-onboarding-marker='guidance']", text: "•", count: guidance_count
      end
    end

    guidance_markers = css_select("[data-onboarding-marker='guidance']")
    assert_equal 4, guidance_markers.size
    guidance_markers.each do |marker|
      assert_includes marker["class"], "text-[#C9C9C6]"
      assert_not_includes marker["class"], "rounded-full"
      assert_not_includes marker["class"].split, "border"
    end

    assert_select "[data-onboarding-optional][data-component='badge'][data-variant='outline']",
      text: "optional",
      count: 1
    assert_select "[data-onboarding-item]", count: 8
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
    assert_drawer_state(terminal: :incomplete, chat: :incomplete, content: :incomplete)
    assert_menu_label "Finish setting up"
  end

  def assert_onboarding_state(terminal:, chat:, content:)
    agent = terminal == :complete || chat == :complete
    completed = [agent, content == :complete].count(true)

    if completed < 2
      assert_alert_progress(
        agent: agent ? :complete : :incomplete,
        content:,
        completed:
      )
      if agent
        assert_alert_message(
          title: "Almost there",
          text: "Almost there — ask your agent to save its first memory."
        )
      else
        assert_alert_message(
          title: "Finish setting up",
          text: "Finish setting up — connect an agent so it can read and write here."
        )
      end
      assert_menu_label "Finish setting up"
    else
      assert_select ALERT_SELECTOR, count: 0
      assert_select MENU_TRIGGER_SELECTOR, count: 0
    end

    assert_global_drawer
    assert_drawer_state(terminal:, chat:, content:)
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

  def assert_drawer_state(terminal:, chat:, content:)
    complete = content == :complete && [terminal, chat].include?(:complete)
    folded_count = [terminal, chat].count(:complete)
    folded_count += 2 if content == :complete
    folded_count += 4 if complete

    assert_select "[data-onboarding-item]", count: 8
    assert_select "[data-onboarding-item][data-folded='true']", count: folded_count
    assert_select "[data-onboarding-item][data-folded='false']", count: 8 - folded_count
    assert_select "[data-onboarding-item-toggle][aria-expanded='false']", count: folded_count
    assert_select "[data-onboarding-item-body][hidden]", count: folded_count

    assert_onboarding_item(
      "[data-onboarding-panel='terminal'] [data-onboarding-item][data-onboarding-step='1']",
      folded: terminal == :complete,
      marker: (terminal == :complete) ? "check" : "number"
    )
    assert_onboarding_item(
      "[data-onboarding-panel='chat'] [data-onboarding-item][data-onboarding-step='1']",
      folded: chat == :complete,
      marker: (chat == :complete) ? "check" : "number"
    )

    %w[terminal chat].each do |panel|
      assert_onboarding_item(
        "[data-onboarding-panel='#{panel}'] [data-onboarding-item][data-onboarding-step='2']",
        folded: content == :complete,
        marker: (content == :complete) ? "check" : "number"
      )
    end

    guidance_items = css_select(
      "[data-onboarding-item][data-onboarding-kind='guidance']"
    )
    assert_equal 4, guidance_items.size
    guidance_items.each do |item|
      assert_onboarding_item_node(item, folded: complete, marker: "guidance")
    end
  end

  def assert_onboarding_item(selector, folded:, marker:)
    items = css_select(selector)
    assert_equal 1, items.size, "expected one onboarding item for #{selector}"
    assert_onboarding_item_node(items.first, folded:, marker:)
  end

  def assert_onboarding_item_node(item, folded:, marker:)
    assert_equal folded.to_s, item["data-folded"]
    assert_equal marker, item.at_css("[data-onboarding-marker]")["data-onboarding-marker"]

    title_classes = item.at_css("[data-onboarding-item-title]")["class"].split
    body = item.at_css("[data-onboarding-item-body]")
    toggles = item.css("[data-onboarding-item-toggle]")

    if folded
      assert_includes title_classes, "font-medium"
      assert_includes title_classes, "text-muted-foreground"
      assert_not_includes title_classes, "font-semibold"
      assert_equal 1, toggles.size
      assert_equal "Show", toggles.first.text.squish
      assert_equal "false", toggles.first["aria-expanded"]
      assert body.attribute("hidden")
    else
      assert_includes title_classes, "font-semibold"
      assert_not_includes title_classes, "font-medium"
      assert_empty toggles
      assert_nil body.attribute("hidden")
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

  def create_oauth_token
    client = OauthClient.create!(
      client_name: "Onboarding request client",
      redirect_uris: ["https://example.com/callback"].to_json
    )
    @user.access_tokens.create!(
      permission: "read_only",
      oauth_client: client,
      expires_at: 1.hour.from_now
    )
  end
end
