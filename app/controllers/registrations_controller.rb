class RegistrationsController < ApplicationController
  layout "security"

  allow_unauthenticated_access only: %i[new create]
  before_action :redirect_authenticated_user, only: %i[new create]
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_registration_url, alert: t("registrations.create.rate_limited") }

  def new
    @user = User.new
  end

  def create
    @user = Account.create_with_user(**registration_params)

    if @user.persisted?
      RegistrationsMailer.welcome(@user).deliver_later
      schedule_onboarding_emails(@user) if multi_tenant?
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

  def schedule_onboarding_emails(user)
    OnboardingMailer.api_token(user).deliver_later(wait: 1.day)
    OnboardingMailer.cli_setup(user).deliver_later(wait: 3.days)
    OnboardingMailer.ai_integration(user).deliver_later(wait: 5.days)
    OnboardingMailer.check_in(user).deliver_later(wait: 7.days)
    OnboardingMailer.advanced_tips(user).deliver_later(wait: 12.days)
  end
end
