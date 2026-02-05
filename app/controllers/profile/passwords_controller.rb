class Profile::PasswordsController < ApplicationController
  def update
    @user = Current.user

    unless @user.authenticate(params[:current_password])
      flash[:alert] = t(".current_password_invalid")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh }
        format.html { redirect_to profile_path }
      end
      return
    end

    if @user.update(password_params)
      ProfileMailer.password_changed(@user).deliver_later
      flash[:notice] = t(".updated")
    else
      flash[:alert] = @user.errors.full_messages.to_sentence
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.refresh }
      format.html { redirect_to profile_path }
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
