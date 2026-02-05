class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user

  def user
    super || session&.user
  end

  def account
    user&.account
  end
end
