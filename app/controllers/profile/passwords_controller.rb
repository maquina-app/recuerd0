class Profile::PasswordsController < ApplicationController
  def update
    @user = Current.user

    unless @user.authenticate(params[:current_password])
      redirect_to profile_path, alert: t(".current_password_invalid"), status: :see_other
      return
    end

    if @user.update(password_params)
      ProfileMailer.password_changed(@user).deliver_later
      redirect_to profile_path, notice: t(".updated"), status: :see_other
    else
      redirect_to profile_path, alert: @user.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
