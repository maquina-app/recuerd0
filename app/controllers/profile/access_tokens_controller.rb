class Profile::AccessTokensController < ApplicationController
  def create
    @access_token = Current.user.access_tokens.manual.build(access_token_params)

    if @access_token.save
      flash[:notice] = t(".created")
      flash[:new_token] = @access_token.raw_token
    else
      flash[:alert] = @access_token.errors.full_messages.to_sentence
    end

    redirect_to profile_path
  end

  def destroy
    @access_token = Current.user.access_tokens.find(params[:id])

    # OAuth-issued tokens are revoked (kept for audit); manual tokens are deleted.
    if @access_token.oauth_client_id?
      @access_token.revoke!
      redirect_to profile_path, notice: t(".disconnected")
    else
      @access_token.destroy
      redirect_to profile_path, notice: t(".deleted")
    end
  end

  private

  def access_token_params
    params.require(:access_token).permit(:description, :permission)
  end
end
