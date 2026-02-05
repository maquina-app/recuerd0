class Profile::AccessTokensController < ApplicationController
  def create
    @access_token = Current.user.access_tokens.build(access_token_params)

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
    @access_token.destroy

    redirect_to profile_path, notice: t(".deleted")
  end

  private

  def access_token_params
    params.require(:access_token).permit(:description, :permission)
  end
end
