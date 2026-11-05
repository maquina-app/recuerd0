# Where a deleted account's users land after signing in during the grace period.
class Account::RecoveriesController < ApplicationController
  include AdminAuthorizable

  layout "security"
  allow_deleted_account

  before_action :set_account
  before_action :require_admin_to_restore, only: :create

  def show
    @latest_export = @account.account_exports.completed.order(completed_at: :desc).first
    @export_in_progress = @account.account_exports.in_progress.exists?
    @exports_this_month = @account.account_exports.exports_this_month.count
  end

  def create
    @account.restore
    track_event("account.restore")
    redirect_to workspaces_path, notice: t(".restored"), status: :see_other
  end

  private

  def set_account
    @account = Current.account
    redirect_to workspaces_path unless @account.deleted?
  end

  def require_admin_to_restore
    return if Current.user.admin?

    redirect_to account_recovery_path, alert: t("accounts.unauthorized"), status: :see_other
  end
end
