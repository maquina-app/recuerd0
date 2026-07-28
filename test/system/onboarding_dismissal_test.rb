require "application_system_test_case"

class OnboardingDismissalTest < ApplicationSystemTestCase
  ALERT_SELECTOR = "[data-onboarding-banner='true']"
  DRAWER_SELECTOR = "#onboarding-drawer"

  setup do
    @user = Account.create_with_user(
      email_address: "system-onboarding@example.com",
      password: "password",
      password_confirmation: "password"
    )

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end

  test "alert opens the drawer and Terminal and Chat always keep one selection" do
    assert_selector ALERT_SELECTOR
    click_button "Show me how"

    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"
    assert_selector "[data-onboarding-panel='terminal']", visible: true
    assert_selector "[data-onboarding-panel='chat']", visible: false
    assert_selector "#onboarding-connection-methods [data-value='terminal'][aria-pressed='true']"

    click_button "Chat"

    assert_selector "[data-onboarding-panel='terminal']", visible: false
    assert_selector "[data-onboarding-panel='chat']", visible: true
    assert_selector "#onboarding-connection-methods [data-value='chat'][aria-pressed='true']"

    click_button "Chat"

    assert_selector "#onboarding-connection-methods [data-value='chat'][aria-pressed='true']"
    assert_selector "#onboarding-connection-methods [aria-pressed='true']", count: 1
    assert_selector "[data-onboarding-panel='chat']", visible: true
  end

  test "closing does not dismiss and dismissal leaves the menu trigger available" do
    click_button "Show me how"
    find("[data-drawer-part='close']").click

    assert_selector "#{DRAWER_SELECTOR}[data-state='closed']", visible: :all
    assert_nil @user.reload.onboarding_dismissed_at

    click_button "Dismiss"

    assert_no_selector ALERT_SELECTOR
    assert_in_delta Time.current, @user.reload.onboarding_dismissed_at, 2.seconds

    find("button[data-sidebar-part='menu-button']").click
    click_button "Getting started · 0 of 2"

    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"
  end

  test "drawer state uses a session cookie and survives a Turbo morph refresh" do
    click_button "Show me how"
    assert_selector "#{DRAWER_SELECTOR}[data-state='open']"

    cookie = page.driver.browser.manage.cookie_named("recuerd0_onboarding_drawer_state")
    assert_equal "true", cookie[:value]
    assert_nil cookie[:expires]

    page.execute_script <<~JAVASCRIPT
      document.addEventListener("turbo:morph", () => {
        document.documentElement.dataset.onboardingMorphed = "true"
      }, { once: true })
      Turbo.session.refresh(document.baseURI, { method: "morph" })
    JAVASCRIPT

    assert_selector "html[data-onboarding-morphed='true']", visible: :all, wait: 5
    assert_selector "#{DRAWER_SELECTOR}[data-state='open']", wait: 5
    assert_nil @user.reload.onboarding_dismissed_at
  end
end
