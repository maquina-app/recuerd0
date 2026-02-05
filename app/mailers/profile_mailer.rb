class ProfileMailer < ApplicationMailer
  def password_changed(user)
    @user = user
    mail subject: default_i18n_subject, to: user.email_address
  end
end
