# Passing and taking ownership, for whichever record the controller sets as
# @ownable: the owner passes to anyone left on the account, an admin takes for themselves.
module OwnershipTransferring
  extend ActiveSupport::Concern

  included do
    allow_token_authentication
    helper_method :ownership_return_path
  end

  def edit
    return deny_ownership_change unless @ownable.owned_by?(Current.user)

    @recipients = Current.account.active_users.where.not(id: Current.user.id).order(:created_at)
    render "ownerships/edit"
  end

  def update
    recipient = Current.account.active_users.find_by(id: params[:user_id])

    if !@ownable.ownership_passable_by?(Current.user, to: recipient)
      deny_ownership_change
    elsif recipient.nil? || @ownable.owned_by?(recipient)
      reject_recipient
    else
      @ownable.pass_ownership_to(recipient)
      track_event("ownership.change", resource: @ownable)
      respond_to do |format|
        format.html { redirect_to ownership_return_path, notice: ownership_notice(recipient), status: :see_other }
        format.json { render json: {id: @ownable.ownership_record.id, owner_id: recipient.id} }
      end
    end
  end

  private

  def ownership_notice(recipient)
    (recipient == Current.user) ? t("ownership.taken") : t("ownership.passed", name: recipient.display_name)
  end

  def deny_ownership_change
    respond_to do |format|
      format.html { redirect_to ownership_return_path, alert: t("ownership.pass_denied"), status: :see_other }
      format.json { render_forbidden(t("ownership.pass_denied")) }
    end
  end

  def reject_recipient
    respond_to do |format|
      format.html { redirect_to ownership_return_path, alert: t("ownership.invalid_recipient"), status: :see_other }
      format.json { render_validation_error(t("ownership.invalid_recipient")) }
    end
  end
end
