class AccountsController < ApplicationController
  include AdminAuthorizable

  before_action :require_admin, only: %i[update destroy]
  rate_limit to: 10, within: 3.minutes, only: :destroy,
    with: -> { redirect_to account_path, alert: t("sessions.create.rate_limited"), status: :see_other }

  def show
    @account = Current.account
    @users = @account.active_users.order(:created_at)
    load_export_data if Current.user.admin?
  end

  def update
    @account = Current.account

    if @account.update(account_params)
      redirect_to account_path, notice: t(".updated"), status: :see_other
    else
      @users = @account.active_users.order(:created_at)
      load_export_data if Current.user.admin?
      flash.now[:alert] = t(".errors")
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    account = Current.account

    unless Current.user.authenticate(params[:password].to_s)
      redirect_to account_path(anchor: "delete-account"), alert: t(".wrong_password"), status: :see_other
      return
    end

    account.schedule_deletion!
    track_event("account.schedule_deletion")

    reset_session
    cookies.delete(:session_id)
    redirect_to new_session_path, notice: t(".deleted", date: l(account.permanent_deletion_on, format: :long)), status: :see_other
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end

  def load_export_data
    @exports_this_month = @account.account_exports.exports_this_month.count
    @current_export = @account.account_exports.in_progress.order(created_at: :desc).first
    @latest_export = @account.account_exports.completed.order(completed_at: :desc).first
    @last_export_failed = @account.account_exports.last_failed?
  end
end
