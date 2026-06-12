require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "fresh session is not expired" do
    session = sessions(:one)
    session.touch

    assert_not session.expired?
  end

  test "session past the idle timeout is expired" do
    session = sessions(:one)
    session.update_column(:updated_at, (Session::IDLE_TIMEOUT + 1.day).ago)

    assert session.expired?
  end
end
