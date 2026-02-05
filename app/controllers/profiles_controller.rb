class ProfilesController < ApplicationController
  def show
    @user = Current.user
    @access_tokens = @user.access_tokens.recent
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      redirect_to profile_path, notice: t(".updated")
    else
      @access_tokens = @user.access_tokens.recent
      flash.now[:alert] = t(".errors")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name)
  end
end
