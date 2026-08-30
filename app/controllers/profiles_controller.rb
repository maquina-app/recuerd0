class ProfilesController < ApplicationController
  def show
    @user = Current.user
    load_tokens
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      redirect_to profile_path, notice: t(".updated"), status: :see_other
    else
      load_tokens
      flash.now[:alert] = t(".errors")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_tokens
    @access_tokens = @user.access_tokens.manual.recent
    # `.active` also requires expires_at in the future, but AccessToken
    # .find_by_refresh_token gates ONLY on revoked_at — deliberately, since a
    # refresh token outliving its access token is the point. So an app whose
    # access token had expired vanished from this list while remaining able to
    # mint new ones indefinitely, and the user was shown "No connected
    # applications" with no way to revoke it. List by the same condition that
    # actually grants access.
    @connected_apps = @user.access_tokens.oauth.where(revoked_at: nil).includes(:oauth_client).recent
  end

  def profile_params
    params.require(:user).permit(:name)
  end
end
