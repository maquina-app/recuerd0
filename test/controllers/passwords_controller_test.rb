require "test_helper"
require "minitest/mock"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  # rate_limit captures its store when the class loads, which in test is the null
  # store, so the count is stubbed on that instance rather than swapped out.
  test "a reset request within the limit sends the email" do
    with_rate_limit_count(5) do
      assert_enqueued_emails 1 do
        post passwords_url, params: {email_address: users(:one).email_address}
      end
    end

    assert_redirected_to new_session_path
  end

  test "a reset request past the limit sends nothing" do
    with_rate_limit_count(6) do
      assert_no_enqueued_emails do
        post passwords_url, params: {email_address: users(:one).email_address}
      end
    end

    assert_redirected_to new_password_path
    assert_equal I18n.t("passwords.create.rate_limited"), flash[:alert]
  end

  private

  def with_rate_limit_count(count, &)
    PasswordsController.cache_store.stub(:increment, count, &)
  end
end
