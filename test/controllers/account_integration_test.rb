require "test_helper"

class AccountIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  # Authentication blocking for deleted accounts
  test "login blocked when account is soft-deleted via session" do
    sign_in_as(@admin)
    get account_url
    assert_response :success

    # Soft-delete the account (simulate admin deleting it)
    @account.soft_delete

    # Next request should be blocked
    get workspaces_url
    assert_redirected_to new_session_path
    assert_equal I18n.t("authentication.account_deleted"), flash[:alert]
  end

  test "API request blocked when account is soft-deleted via token" do
    @account.soft_delete

    get workspaces_url(format: :json),
      headers: {"Authorization" => "Bearer test_full_token_456"}

    assert_response :unauthorized
  end

  # Invitation edge cases
  test "invitation acceptance fails when account at limit during token validity" do
    token = @account.generate_invitation_token

    # Fill up the account to the limit after token was generated
    8.times do |i|
      @account.users.create!(
        email_address: "latecomer#{i}@example.com",
        password: "password",
        role: "member"
      )
    end
    assert @account.at_user_limit?

    # Try to accept the invitation
    post invitations_url, params: {
      token: token,
      user: {
        email_address: "toolate@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_response :unprocessable_entity
  end

  # Account deletion destroys all sessions across all users
  test "account deletion destroys all sessions across all users" do
    # Create sessions for both admin and member
    @admin.sessions.create!(ip_address: "1.1.1.1", user_agent: "Admin Browser")
    @member.sessions.create!(ip_address: "2.2.2.2", user_agent: "Member Browser")

    initial_session_count = Session.where(user_id: @account.user_ids).count
    assert initial_session_count > 0

    sign_in_as(@admin)
    delete account_url

    assert_equal 0, Session.where(user_id: @account.user_ids).count
  end

  # Member cannot access admin-only actions (comprehensive)
  test "member cannot access any admin-only actions" do
    sign_in_as(@member)

    # Cannot update account
    patch account_url, params: {account: {name: "Hacked"}}
    assert_redirected_to account_path
    assert_equal "one", @account.reload.name

    # Cannot delete account
    delete account_url
    assert_redirected_to account_path
    assert_not @account.reload.deleted?

    # Cannot remove users
    delete account_user_url(@admin)
    assert_redirected_to account_path
    assert_not @admin.reload.anonymized?

    # Cannot generate invitations
    post account_invitation_url
    assert_redirected_to account_path
  end
end
