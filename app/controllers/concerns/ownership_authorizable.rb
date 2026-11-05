# Editing a workspace, delete, permanent delete, archive and version purge belong to
# a record's owner or an admin. Hiding the buttons is courtesy; this is the rule.
module OwnershipAuthorizable
  extend ActiveSupport::Concern

  private

  def require_manage_access(record)
    deny_ownership_access unless record.manageable_by?(Current.user)
  end

  # A workspace's owner can also delete what others put in it.
  def require_delete_access(memory)
    deny_ownership_access unless memory.deletable_by?(Current.user)
  end

  def deny_ownership_access
    respond_to do |format|
      format.html { redirect_back_or_to workspaces_path, alert: t("ownership.denied"), status: :see_other }
      format.json { render_forbidden(t("ownership.denied")) }
    end
  end
end
