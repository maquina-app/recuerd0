require "application_system_test_case"

class OnboardingDismissalTest < ApplicationSystemTestCase
  ALERT_SELECTOR = "[data-onboarding-banner='true']"
  DRAWER_SELECTOR = "#onboarding-drawer"
  MENU_TRIGGER_SELECTOR = "[data-onboarding-menu-trigger='true']"

  setup do
    @user = Account.create_with_user(
      email_address: "system-onboarding@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @workspace = @user.account.workspaces.find_by!(name: "My Workspace")

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end

  test "onboarding progresses from zero through completion and stays complete across reloads" do
    assert_alert_state(
      message: "Finish setting up — connect an agent so it can read and write here.",
      agent: :incomplete,
      content: :incomplete,
      completed: 0
    )
    assert_menu_entry_present
    assert_drawer_state(terminal: :incomplete, chat: :incomplete, content: :incomplete)

    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!
    refresh

    assert_alert_state(
      message: "Almost there — ask your agent to save its first memory.",
      agent: :complete,
      content: :incomplete,
      completed: 1
    )
    assert_menu_entry_present
    assert_drawer_state(terminal: :complete, chat: :incomplete, content: :incomplete)

    Memory.create_with_content(
      @workspace,
      title: "First content",
      content: "Body",
      source: nil
    )
    refresh

    assert_completed_manual_onboarding

    refresh

    assert_completed_manual_onboarding
  end

  test "alert opens the drawer and Terminal and Chat always keep one selection" do
    assert_selector ALERT_SELECTOR

    alert_layout = page.evaluate_script <<~JAVASCRIPT
      (() => {
        const alert = document.querySelector("[data-onboarding-banner='true']")
        const icon = alert.querySelector(":scope > svg:first-child")
        const message = alert.querySelector("[data-onboarding-alert-row] > p")
        const pageHeader = alert.nextElementSibling
        const alertRect = alert.getBoundingClientRect()
        const iconRect = icon.getBoundingClientRect()
        const messageRect = message.getBoundingClientRect()
        const pageHeaderRect = pageHeader.getBoundingClientRect()

        return {
          headerGap: pageHeaderRect.top - alertRect.bottom,
          iconMarginTop: Number.parseFloat(getComputedStyle(icon).marginTop),
          centerDifference: Math.abs(
            (iconRect.top + (iconRect.height / 2)) -
            (messageRect.top + (messageRect.height / 2))
          )
        }
      })()
    JAVASCRIPT

    assert_in_delta 32, alert_layout.fetch("headerGap"), 0.5
    assert_in_delta 8, alert_layout.fetch("iconMarginTop"), 0.5
    assert_operator alert_layout.fetch("centerDifference"), :<, 1

    click_button "Show me how"

    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"
    assert_selector "[data-onboarding-panel='terminal']", visible: true
    assert_selector "[data-onboarding-panel='chat']", visible: false
    assert_selector "#onboarding-connection-methods [data-value='terminal'][aria-pressed='true']"

    overlay = page.evaluate_script <<~JAVASCRIPT
      (() => {
        const backdrop = document.querySelector("#onboarding-drawer-backdrop")
        const panel = document.querySelector("#onboarding-drawer-panel")
        const sidebar = document.querySelector("[data-sidebar-part='container']")
        const targets = {
          background: document.querySelector("[data-sidebar-part='inner']"),
          logo: document.querySelector("[data-sidebar-part='header'] img:not(.hidden)"),
          navigation: document.querySelector("[data-sidebar-part='content'] a"),
          userFooter: document.querySelector("[data-sidebar-part='footer'] [data-sidebar-part='menu-button']")
        }
        const backdropRect = backdrop.getBoundingClientRect()
        const covered = Object.fromEntries(
          Object.entries(targets).map(([name, element]) => {
            const rect = element.getBoundingClientRect()
            const topmost = document.elementFromPoint(
              rect.left + (rect.width / 2),
              rect.top + (rect.height / 2)
            )
            return [name, topmost === backdrop]
          })
        )

        return {
          backdropPosition: getComputedStyle(backdrop).position,
          backdropZIndex: Number(getComputedStyle(backdrop).zIndex),
          panelZIndex: Number(getComputedStyle(panel).zIndex),
          sidebarZIndex: Number(getComputedStyle(sidebar).zIndex),
          backdropRect: {
            top: backdropRect.top,
            right: backdropRect.right,
            bottom: backdropRect.bottom,
            left: backdropRect.left
          },
          viewport: {
            width: window.innerWidth,
            height: window.innerHeight
          },
          covered
        }
      })()
    JAVASCRIPT

    assert_equal "fixed", overlay.fetch("backdropPosition")
    assert_operator overlay.fetch("backdropZIndex"), :>, overlay.fetch("sidebarZIndex")
    assert_operator overlay.fetch("panelZIndex"), :>, overlay.fetch("backdropZIndex")
    assert_in_delta 0, overlay.dig("backdropRect", "top"), 0.5
    assert_in_delta 0, overlay.dig("backdropRect", "left"), 0.5
    assert_in_delta overlay.dig("viewport", "width"), overlay.dig("backdropRect", "right"), 0.5
    assert_in_delta overlay.dig("viewport", "height"), overlay.dig("backdropRect", "bottom"), 0.5
    assert overlay.fetch("covered").values.all?,
      "expected the drawer backdrop to cover the sidebar background, logo, navigation, and user footer"

    click_button "Chat"

    assert_selector "[data-onboarding-panel='terminal']", visible: false
    assert_selector "[data-onboarding-panel='chat']", visible: true
    assert_selector "#onboarding-connection-methods [data-value='chat'][aria-pressed='true']"

    click_button "Chat"

    assert_selector "#onboarding-connection-methods [data-value='chat'][aria-pressed='true']"
    assert_selector "#onboarding-connection-methods [aria-pressed='true']", count: 1
    assert_selector "[data-onboarding-panel='chat']", visible: true
  end

  test "dismissal persists from zero through completion while the menu follows completion" do
    click_button "Show me how"
    find("[data-drawer-part='close']").click

    assert_selector "#{DRAWER_SELECTOR}[data-state='closed']", visible: :all
    assert_nil @user.reload.onboarding_dismissed_at

    click_button "Dismiss"

    assert_no_selector ALERT_SELECTOR
    assert_in_delta Time.current, @user.reload.onboarding_dismissed_at, 2.seconds

    refresh

    assert_no_selector ALERT_SELECTOR
    find("button[data-sidebar-part='menu-button']").click
    menu_item_background = page.evaluate_script <<~JAVASCRIPT
      getComputedStyle(
        document.querySelector("[data-onboarding-menu-trigger='true']")
      ).backgroundColor
    JAVASCRIPT
    assert_equal "rgba(0, 0, 0, 0)", menu_item_background
    menu_item = find("[data-onboarding-menu-trigger='true']")
    menu_item.hover
    hover_background = page.evaluate_script <<~JAVASCRIPT
      getComputedStyle(
        document.querySelector("[data-onboarding-menu-trigger='true']")
      ).backgroundColor
    JAVASCRIPT
    assert_not_equal "rgba(0, 0, 0, 0)", hover_background
    menu_item.click

    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"

    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!
    Memory.create_with_content(
      @workspace,
      title: "First content after dismissal",
      content: "Body",
      source: "manual"
    )
    refresh

    assert_no_selector ALERT_SELECTOR
    assert_no_selector MENU_TRIGGER_SELECTOR, visible: :all
    assert_drawer_state(terminal: :complete, chat: :incomplete, content: :complete)
  end

  test "drawer closes on Turbo morph refresh and navigation" do
    click_button "Show me how"
    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"

    cookie = page.driver.browser.manage.all_cookies.find do |candidate|
      candidate[:name] == "recuerd0_onboarding_drawer_state"
    end
    assert_nil cookie

    page.execute_script <<~JAVASCRIPT
      document.addEventListener("turbo:morph", () => {
        document.documentElement.dataset.onboardingMorphed = "true"
      }, { once: true })
      Turbo.session.refresh(document.baseURI, { method: "morph" })
    JAVASCRIPT

    assert_selector "html[data-onboarding-morphed='true']", visible: :all, wait: 5
    assert_selector "#{DRAWER_SELECTOR}[data-state='closed']", visible: :all, wait: 5
    assert_nil @user.reload.onboarding_dismissed_at

    click_button "Show me how"
    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"
    within "[data-onboarding-panel='terminal'] [data-onboarding-item][data-onboarding-step='1']" do
      click_link "Access Tokens"
    end

    assert_current_path profile_path
    assert_selector "#{DRAWER_SELECTOR}[data-state='closed']", visible: :all
  end

  test "a completed tracked step is folded and its Show control expands it" do
    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!

    visit workspaces_path
    click_button "Show me how"

    within "[data-onboarding-panel='terminal'] [data-onboarding-item][data-onboarding-step='1']" do
      assert_selector "[data-onboarding-item-body][hidden]", visible: :all
      assert_button "Show"

      click_button "Show"

      assert_selector "[data-onboarding-item-body]", visible: true
      assert_button "Hide"
      assert_selector "[data-onboarding-item-toggle][aria-expanded='true']"

      click_button "Hide"

      assert_selector "[data-onboarding-item-body][hidden]", visible: :all
      assert_button "Show"
    end
  end

  test "both connection paths and content fold every item and present the drawer as reference" do
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

    visit workspaces_path

    assert_no_selector ALERT_SELECTOR
    assert_no_selector MENU_TRIGGER_SELECTOR, visible: :all
    assert_selector DRAWER_SELECTOR, visible: :all
    assert_selector "a[href='#{start_path}']", text: "Full walkthrough", visible: :all
    assert_drawer_state(terminal: :complete, chat: :complete, content: :complete)
    assert_selector "[data-onboarding-item][data-onboarding-kind='guidance'] [data-onboarding-marker='guidance']",
      count: 4,
      visible: :all
    assert_no_selector "[data-onboarding-item][data-onboarding-kind='guidance'] [data-onboarding-marker='check']",
      visible: :all
  end

  test "command blocks never wrap or widen the 480px drawer" do
    click_button "Show me how"

    metrics = page.evaluate_script <<~JAVASCRIPT
      (() => {
        const panel = document.querySelector("#onboarding-drawer-panel")
        const measurements = Array.from(
          document.querySelectorAll("[data-onboarding-panel='terminal'] [data-onboarding-command] code")
        ).map((code) => {
          const block = code.closest("[data-onboarding-command]")
          const styles = getComputedStyle(code)
          const webkitScrollbar = getComputedStyle(code, "::-webkit-scrollbar")

          return {
            command: code.textContent.trim(),
            blockClientWidth: block.clientWidth,
            blockScrollWidth: block.scrollWidth,
            codeClientWidth: code.clientWidth,
            codeScrollWidth: code.scrollWidth,
            whiteSpace: styles.whiteSpace,
            overflowX: styles.overflowX,
            scrollbarWidth: styles.scrollbarWidth,
            webkitScrollbarHeight: webkitScrollbar.height
          }
        })

        return {
          panelWidth: panel.getBoundingClientRect().width,
          panelClientWidth: panel.clientWidth,
          panelScrollWidth: panel.scrollWidth,
          measurements
        }
      })()
    JAVASCRIPT

    assert_in_delta 480, metrics.fetch("panelWidth"), 0.5
    assert_equal metrics.fetch("panelClientWidth"), metrics.fetch("panelScrollWidth")
    metrics.fetch("measurements").each do |command|
      assert_equal command.fetch("blockClientWidth"), command.fetch("blockScrollWidth")
      assert_equal "nowrap", command.fetch("whiteSpace")
      assert_equal "auto", command.fetch("overflowX")
      assert_equal "thin", command.fetch("scrollbarWidth")
      assert_equal "4px", command.fetch("webkitScrollbarHeight")
    end

    click_button "Chat"
    chat_metrics = page.evaluate_script <<~JAVASCRIPT
      (() => {
        const code = document.querySelector("[data-onboarding-panel='chat'] [data-onboarding-command] code")
        const block = code.closest("[data-onboarding-command]")
        const styles = getComputedStyle(code)

        return {
          blockClientWidth: block.clientWidth,
          blockScrollWidth: block.scrollWidth,
          whiteSpace: styles.whiteSpace,
          overflowX: styles.overflowX
        }
      })()
    JAVASCRIPT

    assert_equal chat_metrics.fetch("blockClientWidth"), chat_metrics.fetch("blockScrollWidth")
    assert_equal "nowrap", chat_metrics.fetch("whiteSpace")
    assert_equal "auto", chat_metrics.fetch("overflowX")
  end

  private

  def assert_alert_state(message:, agent:, content:, completed:)
    assert_selector ALERT_SELECTOR
    assert_selector "#{ALERT_SELECTOR} [data-onboarding-alert-row] > p",
      exact_text: message
    assert_selector(
      "#{ALERT_SELECTOR} [data-onboarding-progress]" \
        "[aria-label='#{completed} of 2 setup steps complete']"
    )
    assert_selector(
      "#{ALERT_SELECTOR} [data-onboarding-pip='agent'][data-state='#{agent}']"
    )
    assert_selector(
      "#{ALERT_SELECTOR} [data-onboarding-pip='content'][data-state='#{content}']"
    )
    assert_selector "#{ALERT_SELECTOR} [data-onboarding-progress] > span.whitespace-nowrap",
      exact_text: "#{completed} of 2"
  end

  def assert_menu_entry_present
    find("button[data-sidebar-part='menu-button']").click
    assert_selector MENU_TRIGGER_SELECTOR, exact_text: "Finish setting up"
    page.send_keys(:escape)
    assert_no_selector MENU_TRIGGER_SELECTOR, visible: true
  end

  def assert_completed_manual_onboarding
    assert_no_selector ALERT_SELECTOR
    assert_no_selector MENU_TRIGGER_SELECTOR, visible: :all
    assert_drawer_state(terminal: :complete, chat: :incomplete, content: :complete)
  end

  def assert_drawer_state(terminal:, chat:, content:)
    onboarding_complete = content == :complete && [terminal, chat].include?(:complete)
    folded_count = [terminal, chat].count(:complete)
    folded_count += 2 if content == :complete
    folded_count += 4 if onboarding_complete

    assert_selector "[data-onboarding-item]", count: 8, visible: :all
    assert_selector "[data-onboarding-item][data-folded='true']",
      count: folded_count,
      visible: :all
    assert_selector "[data-onboarding-item][data-folded='false']",
      count: 8 - folded_count,
      visible: :all
    assert_selector "[data-onboarding-item-body][hidden]",
      count: folded_count,
      visible: :all
    assert_selector "[data-onboarding-item-toggle][aria-expanded='false']",
      count: folded_count,
      visible: :all

    assert_tracked_item(panel: "terminal", step: 1, state: terminal)
    assert_tracked_item(panel: "chat", step: 1, state: chat)
    assert_tracked_item(panel: "terminal", step: 2, state: content)
    assert_tracked_item(panel: "chat", step: 2, state: content)

    guidance_state = onboarding_complete ? :complete : :incomplete
    assert_selector(
      "[data-onboarding-item][data-onboarding-kind='guidance']" \
        "[data-folded='#{onboarding_complete}']",
      count: 4,
      visible: :all
    )
    assert_item_rendering(
      "[data-onboarding-item][data-onboarding-kind='guidance']",
      state: guidance_state,
      count: 4
    )
  end

  def assert_tracked_item(panel:, step:, state:)
    selector = "[data-onboarding-panel='#{panel}'] " \
      "[data-onboarding-item][data-onboarding-step='#{step}']"
    marker = (state == :complete) ? "check" : "number"

    assert_selector "#{selector}[data-folded='#{state == :complete}']",
      count: 1,
      visible: :all
    assert_selector "#{selector} [data-onboarding-marker='#{marker}']",
      count: 1,
      visible: :all
    assert_item_rendering(selector, state:, count: 1)
  end

  def assert_item_rendering(selector, state:, count:)
    if state == :complete
      assert_selector "#{selector} [data-onboarding-item-title].font-medium.text-muted-foreground",
        count:,
        visible: :all
      assert_selector "#{selector} [data-onboarding-item-toggle][aria-expanded='false']",
        count:,
        visible: :all
      assert_selector "#{selector} [data-onboarding-item-body][hidden]",
        count:,
        visible: :all
    else
      assert_selector "#{selector} [data-onboarding-item-title].font-semibold",
        count:,
        visible: :all
      assert_no_selector "#{selector} [data-onboarding-item-toggle]",
        visible: :all
      assert_selector "#{selector} [data-onboarding-item-body]:not([hidden])",
        count:,
        visible: :all
    end
  end

  def create_oauth_token
    client = OauthClient.create!(
      client_name: "Onboarding system client",
      redirect_uris: ["https://example.com/callback"].to_json
    )
    @user.access_tokens.create!(
      permission: "read_only",
      oauth_client: client,
      expires_at: 1.hour.from_now
    )
  end
end
