require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @email = PasswordsMailer.reset(@user)
  end

  test "reset email has correct subject and recipients" do
    assert_equal I18n.t("passwords_mailer.reset.subject"), @email.subject
    assert_equal [@user.email_address], @email.to
    assert_equal ["noreply@recuerd0.ai"], @email.from
  end

  test "reset email contains reset link and security note" do
    assert_match "Reset your password", @email.html_part.body.to_s
    assert_match "15 minutes", @email.html_part.body.to_s
    assert_match "didn't request", @email.html_part.body.to_s
  end

  test "reset email text version contains security note" do
    assert_match "15 minutes", @email.text_part.body.to_s
    assert_match "didn't request", @email.text_part.body.to_s
  end
end
