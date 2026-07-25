class RegistrationsMailer < ApplicationMailer
  def welcome(user)
    @user = user
    @start_here_workspace = user.account.workspaces.find_by(name: "My Workspace")
    mail subject: default_i18n_subject, to: user.email_address
  end
end
