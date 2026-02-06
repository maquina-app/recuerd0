class AccountsController < ApplicationController
  include AdminAuthorizable

  before_action :require_admin, only: %i[update destroy]

  def show
    @account = Current.account
    @users = @account.active_users.order(:created_at)
    load_export_data if Current.user.admin?
  end

  def update
    @account = Current.account

    if @account.update(account_params)
      redirect_to account_path, notice: t(".updated")
    else
      @users = @account.active_users.order(:created_at)
      load_export_data if Current.user.admin?
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

  def load_export_data
    @exports_this_month = @account.account_exports.exports_this_month.count
    @current_export = @account.account_exports.in_progress.order(created_at: :desc).first
    @latest_export = @account.account_exports.completed.order(completed_at: :desc).first
  end
end
