require "test_helper"

class AccountExportMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @account = accounts(:one)
    @admin = users(:one)
    @export = AccountExport.create!(
      account: @account,
      user: @admin,
      status: "completed",
      completed_at: Time.current,
      expires_at: 5.days.from_now
    )
  end

  test "started email sent to requesting user with correct subject" do
    mail = AccountExportMailer.started(@export)
    assert_equal "Your data export has started", mail.subject
    assert_equal [@admin.email_address], mail.to
    assert_match "data export has been started", mail.body.encoded
  end

  test "completed email contains download link" do
    mail = AccountExportMailer.completed(@export)
    assert_equal "Your data export is ready", mail.subject
    assert_equal [@admin.email_address], mail.to
    assert_match "account/exports/#{@export.id}", mail.body.encoded
  end

  test "both emails inherit logo attachment from ApplicationMailer" do
    started_mail = AccountExportMailer.started(@export)
    completed_mail = AccountExportMailer.completed(@export)

    assert started_mail.attachments["recuerdo-email.png"], "Started email should have logo"
    assert completed_mail.attachments["recuerdo-email.png"], "Completed email should have logo"
  end

  test "mailer uses I18n for subjects" do
    started_mail = AccountExportMailer.started(@export)
    completed_mail = AccountExportMailer.completed(@export)

    assert_equal I18n.t("account_export_mailer.started.subject"), started_mail.subject
    assert_equal I18n.t("account_export_mailer.completed.subject"), completed_mail.subject
  end
end
