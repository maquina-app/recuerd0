# Delete, permanent delete, archive and version purge belong to a record's owner
# or an admin. Hiding the buttons is courtesy; this is the rule.
module OwnershipAuthorizable
  extend ActiveSupport::Concern

  private

  def require_manage_access(record)
    return if record.manageable_by?(Current.user)

    respond_to do |format|
      format.html { redirect_back_or_to workspaces_path, alert: t("ownership.denied"), status: :see_other }
      format.json { render_forbidden(t("ownership.denied")) }
    end
  end
end
