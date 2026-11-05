class Account::UsersController < ApplicationController
  include AdminAuthorizable

  before_action :require_admin
  before_action :set_user

  def destroy
    if @user == Current.user
      redirect_to account_path, alert: t(".cannot_remove_self"), status: :see_other
      return
    end

    if @user.admin?
      redirect_to account_path, alert: t(".cannot_remove_admin"), status: :see_other
      return
    end

    recipient = recipient_of_ownership

    if recipient.nil?
      redirect_to account_path, alert: t("ownership.invalid_recipient"), status: :see_other
      return
    end

    @user.remove_from_account!(transfer_to: recipient)

    redirect_to account_path, notice: t(".removed"), status: :see_other
  end

  private

  def recipient_of_ownership
    return Current.account.first_admin if params[:transfer_to].blank?

    Current.account.active_users.where.not(id: @user.id).find_by(id: params[:transfer_to])
  end

  def set_user
    @user = Current.account.users.find(params[:id])
  end
end
