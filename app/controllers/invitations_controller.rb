class InvitationsController < ApplicationController
  layout "security"

  allow_unauthenticated_access
  rate_limit to: 10, within: 1.hour, only: :create

  before_action :set_invitation

  def show
    resume_session
    @user = User.new
  end

  def create
    @user = @account.users.build(invitation_params.merge(role: "member"))

    if @invitation.redeem(@user)
      start_new_session_for @user
      redirect_to workspaces_path, notice: t(".success")
    elsif @invitation.reload.used?
      render :used, status: :gone
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_invitation
    @token = params[:token]
    @invitation = Invitation.find_by_token(@token)
    @account = @invitation&.account

    if @account.nil? || @account.deleted?
      render :error, status: :unprocessable_entity
    elsif @invitation.used?
      render :used, status: :gone
    elsif @account.at_user_limit?
      flash.now[:alert] = t("invitations.account_full")
      render :error, status: :unprocessable_entity
    end
  end

  def invitation_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
