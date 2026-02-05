class ProfilesController < ApplicationController
  def show
    @user = Current.user
    @access_tokens = @user.access_tokens.order(created_at: :desc)
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      flash[:notice] = t(".updated")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.refresh }
        format.html { redirect_to profile_path }
      end
    else
      @access_tokens = @user.access_tokens.order(created_at: :desc)
      flash.now[:alert] = t(".errors")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name)
  end
end
