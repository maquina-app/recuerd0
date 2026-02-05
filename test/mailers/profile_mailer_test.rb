require "test_helper"

class ProfileMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @email = ProfileMailer.password_changed(@user)
  end

  test "password_changed email has correct subject and recipients" do
    assert_equal I18n.t("profile_mailer.password_changed.subject"), @email.subject
    assert_equal [@user.email_address], @email.to
    assert_equal ["noreply@recuerd0.ai"], @email.from
  end

  test "password_changed HTML contains security warning and reset link" do
    html = @email.html_part.body.to_s
    assert_match "password was recently changed", html
    assert_match "didn't make this change", html
    assert_match "Reset your password", html
  end

  test "password_changed text version contains security warning" do
    text = @email.text_part.body.to_s
    assert_match "password was recently changed", text
    assert_match "didn't make this change", text
  end

  test "password_changed text version contains reset URL" do
    text = @email.text_part.body.to_s
    assert_match "/passwords/new", text
  end
end
