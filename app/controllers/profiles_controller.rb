class ProfilesController < ApplicationController
  def show
    @user = Current.user
    load_tokens
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      redirect_to profile_path, notice: t(".updated")
    else
      load_tokens
      flash.now[:alert] = t(".errors")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_tokens
    @access_tokens = @user.access_tokens.manual.recent
    @connected_apps = @user.access_tokens.oauth.active.includes(:oauth_client).recent
  end

  def profile_params
    params.require(:user).permit(:name)
  end
end
