require "test_helper"

class Account::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  test "destroy anonymizes user email and destroys sessions" do
    sign_in_as(@admin)

    # Create a session for the member
    @member.sessions.create!(ip_address: "127.0.0.1", user_agent: "Test")
    assert @member.sessions.count > 0

    delete account_user_url(@member), headers: {"HTTP_REFERER" => account_url}

    assert_redirected_to account_path
    assert @member.reload.anonymized?
    assert_equal 0, @member.sessions.count
  end

  test "destroy prevents admin from removing themselves" do
    sign_in_as(@admin)

    delete account_user_url(@admin)

    assert_redirected_to account_path
    assert_not @admin.reload.anonymized?
    assert_equal I18n.t("account.users.destroy.cannot_remove_self"), flash[:alert]
  end

  test "destroy prevents member from removing users" do
    sign_in_as(@member)

    delete account_user_url(@admin)

    assert_redirected_to account_path
    assert_not @admin.reload.anonymized?
    assert_equal I18n.t("accounts.unauthorized"), flash[:alert]
  end
end
