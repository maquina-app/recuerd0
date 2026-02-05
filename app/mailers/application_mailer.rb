class ApplicationMailer < ActionMailer::Base
  default from: "recuerd0 <noreply@recuerd0.ai>"
  layout "mailer"

  before_action :attach_logo

  private

  def attach_logo
    attachments.inline["recuerdo-email.png"] = Rails.root.join("app/assets/images/recuerdo-email.png").read
  end
end
