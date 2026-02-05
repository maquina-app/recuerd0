require "test_helper"

class AccountViewsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  test "admin sees all sections" do
    sign_in_as(@admin)
    get account_url

    assert_response :success
    assert_select "[data-card-part='title']", text: "Account Settings"
    assert_select "[data-card-part='title']", text: "Users"
    assert_select "[data-card-part='title']", text: "Invite Users"
    assert_select "[data-card-part='title'].text-destructive", text: "Delete Account"
  end

  test "member sees read-only view without admin sections" do
    sign_in_as(@member)
    get account_url

    assert_response :success
    assert_select "[data-card-part='title']", text: "Account Settings"
    assert_select "[data-card-part='title']", text: "Users"
    # Should not see invitation or danger zone sections
    assert_select "[data-card-part='title']", text: "Invite Users", count: 0
    assert_select "[data-card-part='title'].text-destructive", count: 0
  end

  test "user list shows role badges" do
    sign_in_as(@admin)
    get account_url

    assert_response :success
    assert_select "[data-component='badge']", text: "Admin"
    assert_select "[data-component='badge']", text: "Member"
  end

  test "admin can update account name" do
    sign_in_as(@admin)
    patch account_url, params: {account: {name: "Updated Name"}}

    assert_redirected_to account_path
    assert_equal "Updated Name", @account.reload.name
  end

  test "invitation link displayed after generation" do
    sign_in_as(@admin)
    post account_invitation_url
    follow_redirect!

    assert_response :success
    assert_select "input[readonly]"
  end
end
