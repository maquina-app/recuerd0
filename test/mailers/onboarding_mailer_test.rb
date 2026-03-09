require "test_helper"

class OnboardingMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:two)
  end

  # api_token

  test "api_token email has correct subject and recipients" do
    user = users(:member) # no access tokens
    email = OnboardingMailer.api_token(user)
    assert_equal I18n.t("onboarding_mailer.api_token.subject"), email.subject
    assert_equal [user.email_address], email.to
    assert_equal ["noreply@recuerd0.ai"], email.from
  end

  test "api_token HTML contains key content" do
    user = users(:member)
    email = OnboardingMailer.api_token(user)
    body = email.html_part.body.to_s
    assert_match "API token", body
    assert_match "Access Tokens", body
    assert_match "btn", body
  end

  test "api_token text contains key content" do
    user = users(:member)
    email = OnboardingMailer.api_token(user)
    assert_match "API token", email.text_part.body.to_s
  end

  test "api_token skipped when user already has tokens" do
    user = users(:one) # has access_tokens in fixtures
    email = OnboardingMailer.api_token(user)
    assert_nil email.to
  end

  test "api_token skipped for anonymized user" do
    user = users(:member)
    user.update!(email_address: "deleted-abc123@example.com")
    email = OnboardingMailer.api_token(user)
    assert_nil email.to
  end

  # cli_setup

  test "cli_setup email has correct subject and recipients" do
    email = OnboardingMailer.cli_setup(@user)
    assert_equal I18n.t("onboarding_mailer.cli_setup.subject"), email.subject
    assert_equal [@user.email_address], email.to
  end

  test "cli_setup HTML contains install command" do
    email = OnboardingMailer.cli_setup(@user)
    assert_match "brew install", email.html_part.body.to_s
  end

  test "cli_setup text contains install command" do
    email = OnboardingMailer.cli_setup(@user)
    assert_match "brew install", email.text_part.body.to_s
  end

  # ai_integration

  test "ai_integration email has correct subject and recipients" do
    email = OnboardingMailer.ai_integration(@user)
    assert_equal I18n.t("onboarding_mailer.ai_integration.subject"), email.subject
    assert_equal [@user.email_address], email.to
  end

  test "ai_integration HTML mentions Claude Code" do
    email = OnboardingMailer.ai_integration(@user)
    assert_match "Claude Code", email.html_part.body.to_s
  end

  test "ai_integration text mentions Claude Code" do
    email = OnboardingMailer.ai_integration(@user)
    assert_match "Claude Code", email.text_part.body.to_s
  end

  # check_in

  test "check_in email has correct subject and recipients" do
    email = OnboardingMailer.check_in(@user)
    assert_equal I18n.t("onboarding_mailer.check_in.subject"), email.subject
    assert_equal [@user.email_address], email.to
  end

  test "check_in HTML shows progress for active user" do
    user = users(:one) # has workspaces and tokens
    email = OnboardingMailer.check_in(user)
    body = email.html_part.body.to_s
    assert_match "Your progress so far", body
    assert_match "set up", body
  end

  test "check_in HTML shows encouragement for inactive user" do
    # Account two has 1 workspace, 0 memories — destroy tokens to hit inactive path
    user = users(:two)
    user.access_tokens.destroy_all
    email = OnboardingMailer.check_in(user)
    body = email.html_part.body.to_s
    # Account two has 1 workspace, 0 memories, no tokens → inactive path
    assert_match "haven't had a chance", body
  end

  test "check_in text contains help links" do
    email = OnboardingMailer.check_in(@user)
    assert_match "Report an issue", email.text_part.body.to_s
  end

  # advanced_tips

  test "advanced_tips email has correct subject and recipients" do
    user = users(:one) # has workspaces beyond "Start Here"
    email = OnboardingMailer.advanced_tips(user)
    assert_equal I18n.t("onboarding_mailer.advanced_tips.subject"), email.subject
    assert_equal [user.email_address], email.to
  end

  test "advanced_tips HTML contains FTS5 examples" do
    user = users(:one)
    email = OnboardingMailer.advanced_tips(user)
    assert_match "FTS5", email.html_part.body.to_s
  end

  test "advanced_tips text contains versioning info" do
    user = users(:one)
    email = OnboardingMailer.advanced_tips(user)
    assert_match "versioning", email.text_part.body.to_s
  end

  test "advanced_tips skipped when user has only Start Here workspace" do
    # User two has a single workspace "Personal" — rename it to simulate
    workspace = @user.account.workspaces.active.first
    workspace.update!(name: "Start Here")
    email = OnboardingMailer.advanced_tips(@user)
    assert_nil email.to
  end

  # inline icons

  test "all emails include inline icon attachments" do
    email = OnboardingMailer.cli_setup(@user)
    attachment_names = email.attachments.map(&:filename)
    assert_includes attachment_names, "onboarding-cli.png"
    assert_includes attachment_names, "onboarding-api.png"
  end
end
