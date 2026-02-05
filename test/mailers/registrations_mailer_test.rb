require "test_helper"

class RegistrationsMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @email = RegistrationsMailer.welcome(@user)
  end

  test "welcome email has correct subject and recipients" do
    assert_equal I18n.t("registrations_mailer.welcome.subject"), @email.subject
    assert_equal [@user.email_address], @email.to
    assert_equal ["noreply@recuerd0.ai"], @email.from
  end

  test "welcome email HTML contains branded content" do
    assert_match "recuerd0", @email.html_part.body.to_s
    assert_match "workspaces", @email.html_part.body.to_s
  end

  test "welcome email text contains key information" do
    assert_match "Welcome to recuerd0", @email.text_part.body.to_s
    assert_match "never share it, sell it", @email.text_part.body.to_s
  end
end
