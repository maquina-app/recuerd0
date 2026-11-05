class Profile::AccessTokensController < ApplicationController
  def create
    @access_token = Current.user.access_tokens.manual.build(access_token_params)
    @access_token.description = t(".default_description", date: l(Date.current, format: :long)) if @access_token.description.blank?

    if @access_token.save
      flash[:notice] = t(".created")
      flash[:new_token] = @access_token.raw_token
    else
      flash[:alert] = @access_token.errors.full_messages.to_sentence
    end

    redirect_to profile_path, status: :see_other
  end

  def destroy
    @access_token = Current.user.access_tokens.find(params[:id])

    # OAuth-issued tokens are revoked (kept for audit); manual tokens are deleted.
    if @access_token.oauth_client_id?
      @access_token.revoke!
      redirect_to profile_path, notice: t(".disconnected"), status: :see_other
    else
      @access_token.destroy
      redirect_to profile_path, notice: t(".deleted"), status: :see_other
    end
  end

  private

  def access_token_params
    params.require(:access_token).permit(:description, :permission)
  end
end
