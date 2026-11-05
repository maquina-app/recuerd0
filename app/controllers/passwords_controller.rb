class PasswordsController < ApplicationController
  layout "security"

  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]

  def new
  end

  def create
    if (user = User.find_by(email_address: params[:email_address]))
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: t(".sent")
  end

  def edit
  end

  # People reset a password when they suspect someone else has access, so it ends
  # every session. Tokens keep working, since agents depend on them, and the notice
  # says so.
  def update
    if @user.reset_password(params.permit(:password, :password_confirmation))
      redirect_to new_session_path, notice: t(".success"), status: :see_other
    else
      flash.now[:alert] = @user.errors.map(&:message).to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: t("passwords.invalid_token")
  end
end
