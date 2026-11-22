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

  test "a session in daily use expires once it is older than the absolute limit" do
    session = sessions(:one)
    session.update_columns(created_at: (Session::ABSOLUTE_TIMEOUT + 1.day).ago, updated_at: Time.current)

    assert session.expired?
  end

  test "a session within the absolute limit is not expired" do
    session = sessions(:one)
    session.update_columns(created_at: (Session::ABSOLUTE_TIMEOUT - 1.day).ago, updated_at: Time.current)

    assert_not session.expired?
  end
end
