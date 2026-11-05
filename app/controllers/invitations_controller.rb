class InvitationsController < ApplicationController
  layout "security"

  allow_unauthenticated_access
  rate_limit to: 10, within: 1.hour, only: :create

  before_action :set_account_from_token

  def show
    resume_session
    @user = User.new
  end

  def create
    @user = @account.users.build(invitation_params.merge(role: "member"))

    if save_new_member
      start_new_session_for @user
      redirect_to workspaces_path, notice: t(".success")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  # The validation catches an email that is already registered; the unique index
  # catches two people racing for it.
  def save_new_member
    @user.save
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:email_address, :taken)
    false
  end

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
