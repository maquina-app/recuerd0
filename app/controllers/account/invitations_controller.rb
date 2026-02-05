class Account::InvitationsController < ApplicationController
  include AdminAuthorizable

  before_action :require_admin

  def create
    account = Current.account

    if account.at_user_limit?
      redirect_to account_path, alert: t(".limit_reached")
      return
    end

    token = account.generate_invitation_token
    invitation_url = invitation_url(token: token)

    redirect_to account_path, flash: {notice: t(".created"), invitation_url: invitation_url}
  end
end
