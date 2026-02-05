class InvitationsController < ApplicationController
  layout "security"

  allow_unauthenticated_access
  rate_limit to: 10, within: 1.hour, only: :create

  before_action :set_account_from_token

  def show
    @user = User.new
  end

  def create
    @user = @account.users.build(invitation_params.merge(role: "member"))

    if @user.save
      start_new_session_for @user
      redirect_to workspaces_path, notice: t(".success")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_account_from_token
    @token = params[:token]
    @account = Account.find_by_invitation_token(@token)

    if @account.nil?
      render :error, status: :unprocessable_entity
    elsif @account.at_user_limit?
      flash.now[:alert] = t("invitations.account_full")
      render :error, status: :unprocessable_entity
    end
  end

  def invitation_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
