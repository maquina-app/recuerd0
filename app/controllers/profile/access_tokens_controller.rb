class Profile::AccessTokensController < ApplicationController
  def create
    @access_token = Current.user.access_tokens.build(access_token_params)

    if @access_token.save
      flash[:notice] = t(".created")
      flash[:new_token] = @access_token.raw_token
    else
      flash[:alert] = @access_token.errors.full_messages.to_sentence
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.refresh }
      format.html { redirect_to profile_path }
    end
  end

  def destroy
    @access_token = Current.user.access_tokens.find(params[:id])
    @access_token.destroy

    flash[:notice] = t(".deleted")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.refresh }
      format.html { redirect_to profile_path }
    end
  end

  private

  def access_token_params
    params.require(:access_token).permit(:description, :permission)
  end
end
