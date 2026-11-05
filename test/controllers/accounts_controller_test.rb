require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  # show
  test "show renders for authenticated admin" do
    sign_in_as(@admin)
    get account_url
    assert_response :success
  end

  test "show renders for authenticated member" do
    sign_in_as(@member)
    get account_url
    assert_response :success
  end

  test "show redirects unauthenticated user to login" do
    get account_url
    assert_redirected_to new_session_url
  end

  # update
  test "update changes account name for admin" do
    sign_in_as(@admin)
    patch account_url, params: {account: {name: "New Name"}}

    assert_redirected_to account_path
    assert_equal "New Name", @account.reload.name
    assert_equal I18n.t("accounts.update.updated"), flash[:notice]
  end

  test "update rejects blank name" do
    sign_in_as(@admin)
    patch account_url, params: {account: {name: ""}}

    assert_response :unprocessable_entity
  end

  test "update rejects request from member" do
    sign_in_as(@member)
    patch account_url, params: {account: {name: "Hacked"}}

    assert_redirected_to account_path
    assert_equal "one", @account.reload.name
    assert_equal I18n.t("accounts.unauthorized"), flash[:alert]
  end

  # destroy
  test "destroy soft-deletes account for admin" do
    sign_in_as(@admin)

    delete account_url, params: {password: "password"}

    assert_redirected_to new_session_path
    assert @account.reload.deleted?
    assert_equal I18n.t("accounts.destroy.deleted", date: I18n.l(@account.permanent_deletion_on, format: :long)), flash[:notice]
  end

  test "destroy needs the admin's password" do
    sign_in_as(@admin)

    delete account_url, params: {password: "wrong"}

    assert_redirected_to account_path(anchor: "delete-account")
    assert_not @account.reload.deleted?
    assert_equal I18n.t("accounts.destroy.wrong_password"), flash[:alert]
  end

  test "destroy leaves every email intact so the account can come back" do
    sign_in_as(@admin)

    assert_no_changes -> { @account.users.reload.map(&:email_address).sort } do
      delete account_url, params: {password: "password"}
    end
  end

  test "destroy rejects request from member" do
    sign_in_as(@member)

    delete account_url

    assert_redirected_to account_path
    assert_not @account.reload.deleted?
  end
end
