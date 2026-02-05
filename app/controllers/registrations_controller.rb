class RegistrationsController < ApplicationController
  layout "security"

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_registration_url, alert: t("registrations.create.rate_limited") }

  def new
    @user = User.new
  end

  def create
    @user = Account.create_with_user(**registration_params)

    if @user.persisted?
      RegistrationsMailer.welcome(@user).deliver_later
      start_new_session_for @user
      redirect_to workspaces_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation).to_h.symbolize_keys
  end
end
