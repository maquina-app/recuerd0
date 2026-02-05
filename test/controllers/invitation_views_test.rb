require "test_helper"

class InvitationViewsTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @token = @account.generate_invitation_token
  end

  test "invitation show page renders registration form with account name" do
    get invitation_url(token: @token)

    assert_response :success
    assert_select "[data-card-part='title']", text: /Join #{@account.name}/
    assert_select "input[name='user[email_address]']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
    assert_select "input[name='token'][type='hidden']"
  end

  test "invitation error page renders for invalid token" do
    get invitation_url(token: "bad-token")

    assert_response :unprocessable_entity
    assert_select "strong", text: "Invalid Invitation"
  end

  test "sidebar Account link points to account_path" do
    sign_in_as(users(:one))
    get workspaces_url

    assert_response :success
    assert_select "a[href='#{account_path}']", text: /Account/
  end
end
