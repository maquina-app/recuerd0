module AdminAuthorizable
  extend ActiveSupport::Concern

  private

  def require_admin
    return if Current.user.admin?

    redirect_to (Current.account.deleted? ? account_recovery_path : account_path), alert: t("accounts.unauthorized"), status: :see_other
  end
end
