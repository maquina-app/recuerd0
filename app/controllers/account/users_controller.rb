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

    @user.sessions.delete_all
    @user.anonymize_email!

    redirect_to account_path, notice: t(".removed"), status: :see_other
  end

  private

  def set_user
    @user = Current.account.users.find(params[:id])
  end
end
