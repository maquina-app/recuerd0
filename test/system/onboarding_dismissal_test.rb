require "application_system_test_case"

class OnboardingDismissalTest < ApplicationSystemTestCase
  BANNER_SELECTOR = "[data-onboarding-banner='true']"

  setup do
    @user = Account.create_with_user(
      email_address: "system-onboarding@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end

  test "dismissing onboarding persists across visits" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_selector BANNER_SELECTOR
    click_button "Dismiss"
    assert_no_selector BANNER_SELECTOR

    visit workspaces_path
    assert_no_selector BANNER_SELECTOR
  end
end
