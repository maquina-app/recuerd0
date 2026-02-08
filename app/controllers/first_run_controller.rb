class FirstRunController < ApplicationController
  layout "security"

  allow_unauthenticated_access
  before_action :require_single_tenant_mode
  before_action :require_no_accounts

  def new
    @user = User.new
  end

  def create
    @user = Account.create_with_user(**registration_params)

    if @user.persisted?
      start_new_session_for @user
      redirect_to workspaces_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_single_tenant_mode
    redirect_to root_path if multi_tenant?
  end

  def require_no_accounts
    redirect_to root_path if Account.exists?
  end

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation).to_h.symbolize_keys
  end
end
