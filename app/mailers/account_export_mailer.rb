class AccountExportMailer < ApplicationMailer
  def started(export)
    @export = export
    @user = export.user
    mail subject: default_i18n_subject, to: @user.email_address
  end

  def completed(export)
    @export = export
    @user = export.user
    mail subject: default_i18n_subject, to: @user.email_address
  end
end
