require "test_helper"

class Account::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  test "create generates invitation token for admin" do
    sign_in_as(@admin)

    post account_invitation_url

    assert_redirected_to account_path
    assert_equal I18n.t("account.invitations.create.created"), flash[:notice]
    assert flash[:invitation_url].present?
  end

  test "create fails when at user limit" do
    sign_in_as(@admin)

    # Fill up the account to the limit
    3.times do |i|
      @account.users.create!(
        email_address: "fill#{i}@example.com",
        password: "password",
        role: "member"
      )
    end
    assert @account.at_user_limit?

    post account_invitation_url

    assert_redirected_to account_path
    assert_equal I18n.t("account.invitations.create.limit_reached"), flash[:alert]
  end

  test "create rejects member request" do
    sign_in_as(@member)

    post account_invitation_url

    assert_redirected_to account_path
    assert_equal I18n.t("accounts.unauthorized"), flash[:alert]
  end
end
