require "test_helper"

class RegistrationsMailerTest < ActionMailer::TestCase
  setup do
    @user = Account.create_with_user(
      email_address: "welcome@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @workspace = @user.account.workspaces.find_by!(name: "My Workspace")
    @email = RegistrationsMailer.welcome(@user)
  end

  test "welcome email has correct subject and recipients" do
    assert_equal I18n.t("registrations_mailer.welcome.subject"), @email.subject
    assert_equal [@user.email_address], @email.to
    assert_equal ["noreply@recuerd0.ai"], @email.from
  end

  test "welcome email HTML contains branded content" do
    body = @email.html_part.body.to_s
    start_url = Rails.application.routes.url_helpers.start_url(host: "example.com")
    workspace_url = Rails.application.routes.url_helpers.workspace_url(@workspace, host: "example.com")

    assert_match "recuerd0", body
    assert_includes body, "<strong>My Workspace</strong>"
    assert_includes body, start_url
    assert_includes body, "Getting Started guide"
    assert_includes body, workspace_url
    assert_includes body, "Open My Workspace"
    assert_not_includes body, ["five onboarding", "memories"].join(" ")
  end

  test "welcome email text contains key information" do
    body = @email.text_part.body.to_s
    start_url = Rails.application.routes.url_helpers.start_url(host: "example.com")

    assert_match "Welcome to recuerd0", body
    assert_includes body, "My Workspace"
    assert_includes body, "Open My Workspace"
    assert_includes body, start_url
    assert_includes body, "Getting Started: #{start_url}"
    assert_match "never share it, sell it", body
    assert_not_includes body, ["five onboarding", "memories"].join(" ")
  end
end
