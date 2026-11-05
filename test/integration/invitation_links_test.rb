require "test_helper"

# A link works for one person, and removing someone leaves nothing they can come back
# through.
class InvitationLinksTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @token = @account.generate_invitation_token
  end

  def join(token, email:, password: "password123")
    post invitations_url, params: {token: token, user: {email_address: email, password: password, password_confirmation: password}}
  end

  test "a link works once, and opening it again says so instead of showing the form" do
    assert_difference("User.count") { join(@token, email: "first@example.com") }
    delete session_url

    get invitation_url(token: @token)
    assert_response :gone
    assert_match I18n.t("invitations.used.heading"), response.body
    assert_select "form", count: 0

    assert_no_difference("User.count") { join(@token, email: "second@example.com") }
    assert_response :gone
  end

  test "a signup that fails validation leaves the link usable" do
    assert_no_difference("User.count") { join(@token, email: "first@example.com", password: "short") }
    assert_response :unprocessable_entity
    assert_select "form"

    assert_difference("User.count") { join(@token, email: "first@example.com") }
  end

  test "of two submissions already past the check, only one joins" do
    first = Invitation.find_by_token(@token)
    second = Invitation.find_by_token(@token)

    assert first.redeem(@account.users.build(email_address: "a@example.com", password: "password123", role: "member"))
    assert_not second.redeem(@account.users.build(email_address: "b@example.com", password: "password123", role: "member"))
    assert_not User.exists?(email_address: "b@example.com")
  end

  test "a taken email neither joins nor spends the link" do
    invitation = Invitation.find_by_token(@token)

    assert_not invitation.redeem(@account.users.build(email_address: users(:one).email_address, password: "password123", role: "member"))
    assert_not invitation.reload.used?
  end

  test "generating a new link leaves other unused ones working" do
    other = @account.generate_invitation_token

    join(@token, email: "first@example.com")
    delete session_url

    assert_difference("User.count") { join(other, email: "second@example.com") }
  end

  test "an expired or unreadable link is simply invalid" do
    get invitation_url(token: "garbage")
    assert_response :unprocessable_entity

    travel Invitation::EXPIRES_IN + 1.day do
      get invitation_url(token: @token)
      assert_response :unprocessable_entity
    end
  end

  test "a link on a deleted account is invalid" do
    @account.soft_delete

    get invitation_url(token: @token)

    assert_response :unprocessable_entity
  end

  test "revoking ends unused links and a used one still says it was used" do
    used = @account.generate_invitation_token
    join(used, email: "first@example.com")
    delete session_url

    @account.revoke_invitations!

    get invitation_url(token: @token)
    assert_response :unprocessable_entity
    get invitation_url(token: used)
    assert_response :gone
  end

  test "a removed member cannot rejoin through the link that brought them in" do
    join(@token, email: "joined@example.com")
    joined = User.find_by!(email_address: "joined@example.com")
    delete session_url

    sign_in_as(users(:one))
    delete account_user_url(joined)
    delete session_url

    assert_no_difference("User.count") { join(@token, email: "joined@example.com") }
    assert_response :gone
  end

  test "removing a user ends every unused link, and the dialog said it would" do
    pending = @account.generate_invitation_token
    sign_in_as(users(:one))

    get account_url
    assert_match(/Every unused invitation link stops working/, response.body)

    delete account_user_url(users(:member))
    delete session_url

    get invitation_url(token: pending)
    assert_response :unprocessable_entity
  end

  test "the copy says a link is for one person" do
    sign_in_as(users(:one))

    post account_invitation_url
    follow_redirect!

    assert_match I18n.t("accounts.invitations.link_hint"), response.body
    assert_no_match(/Anyone with this link/, response.body)
  end

  test "purging an account takes its invitations with it" do
    @account.schedule_deletion!

    assert_difference("Invitation.count", -@account.invitations.count) { @account.purge! }
  end
end
