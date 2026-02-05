module AdminAuthorizable
  extend ActiveSupport::Concern

  private

  def require_admin
    return if Current.user.admin?

    redirect_to account_path, alert: t("accounts.unauthorized")
  end
end
