class SessionsController < ApplicationController
  layout "security"

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: t("sessions.create.rate_limited") }

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      start_new_session_for user
      track_event("auth.sign_in")
      redirect_to after_authentication_url
    else
      track_event("auth.sign_in_failed", metadata: {email_hash: Digest::SHA256.hexdigest(params[:email_address].to_s.downcase)[0, 12]})
      redirect_to new_session_path, alert: t(".invalid")
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
