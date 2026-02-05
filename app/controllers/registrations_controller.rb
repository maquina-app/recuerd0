class RegistrationsController < ApplicationController
  layout "security"

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_registration_url, alert: t("registrations.create.rate_limited") }

  def new
    @user = User.new
  end

  def create
    result = Account.create_with_user(
      email_address: registration_params[:email_address],
      password: registration_params[:password],
      password_confirmation: registration_params[:password_confirmation]
    )

    if result.is_a?(User) && result.persisted?
      start_new_session_for result
      redirect_to workspaces_path, notice: t(".success")
    else
      @user = result.is_a?(User) ? result : User.new(registration_params.except(:password, :password_confirmation))
      @user.errors.add(:base, t(".failed")) if @user.errors.empty?
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
