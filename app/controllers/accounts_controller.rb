class AccountsController < ApplicationController
  include AdminAuthorizable

  before_action :require_admin, only: %i[update destroy]

  def show
    @account = Current.account
    @users = @account.active_users.order(:created_at)
  end

  def update
    @account = Current.account

    if @account.update(account_params)
      redirect_to account_path, notice: t(".updated")
    else
      @users = @account.active_users.order(:created_at)
      flash.now[:alert] = t(".errors")
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    account = Current.account
    account.anonymize_users!
    account.soft_delete

    reset_session
    cookies.delete(:session_id)
    redirect_to root_path, notice: t(".deleted")
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end
end
