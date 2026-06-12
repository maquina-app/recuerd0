class Session < ApplicationRecord
  belongs_to :user

  # Sessions go stale after this much inactivity. `updated_at` is refreshed on
  # each authenticated request (see Authentication#find_session_by_cookie), so
  # this acts as a rolling idle timeout that limits the window of a stolen cookie.
  IDLE_TIMEOUT = 30.days

  def expired?
    updated_at < IDLE_TIMEOUT.ago
  end
end
