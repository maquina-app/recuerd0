require "test_helper"

class SignupAndEditingTest < ActionDispatch::IntegrationTest
  # --- naming the account ---------------------------------------------------------

  def signup_params(account_name:, email: "new@example.com")
    {user: {account_name: account_name, email_address: email, password: "password123", password_confirmation: "password123"}}
  end

  test "signup asks for the account name and uses it on invitations" do
    get new_registration_url
    assert_select "input[name='user[account_name]'][required]"

    post registration_url, params: signup_params(account_name: "Acme Research")

    account = User.find_by!(email_address: "new@example.com").account
    assert_equal "Acme Research", account.name
    assert account.named?

    delete session_url
    get invitation_url(token: account.generate_invitation_token)
    assert_match "Join Acme Research", response.body
  end

  test "a blank account name is refused next to the field, keeping what was typed" do
    assert_no_difference(["Account.count", "User.count"]) do
      post registration_url, params: signup_params(account_name: "  ")
    end

    assert_response :unprocessable_entity
    assert_select "[data-form-part='error']", text: /blank/
    assert_select "input[name='user[email_address]'][value=?]", "new@example.com"
  end

  test "every invalid field reports at once" do
    post registration_url, params: {user: {account_name: "", email_address: "new@example.com", password: "short", password_confirmation: "short"}}

    assert_select "#user_account_name_error"
    assert_select "#user_password_error"
  end

  test "the name survives an email that is already taken" do
    post registration_url, params: signup_params(account_name: "Acme", email: users(:one).email_address)

    assert_response :unprocessable_entity
    assert_select "input[name='user[account_name]'][value=?]", "Acme"
  end

  test "an existing unnamed account reads generically and its field starts empty" do
    account = accounts(:one)
    account.update!(name: users(:one).email_address.split("@").first)

    get invitation_url(token: account.generate_invitation_token)
    assert_match "Join this team", response.body

    sign_in_as(users(:one))
    get account_url
    assert_select "input[name='account[name]']:not([value])"
  end

  # --- signed-in password change --------------------------------------------------

  test "changing the password refuses a blank one on the server" do
    user = users(:one)
    sign_in_as(user)
    digest = user.reload.password_digest

    patch profile_password_url, params: {current_password: "password", password: "", password_confirmation: ""}

    assert_not_equal I18n.t("profile.passwords.update.updated"), flash[:notice]
    assert flash[:alert].present?
    assert_equal digest, user.reload.password_digest
  end

  # --- the conflict screen and the no-changes screen --------------------------------

  setup do
    @workspace = workspaces(:one)
    @memory = Memory.create_with_content(@workspace, title: "T", content: "first", created_by: users(:one))
  end

  test "the conflict screen offers only the save that keeps both" do
    sign_in_as(users(:one))

    get edit_workspace_memory_url(@workspace, @memory)
    assert_select "button[name='save_as'][value='in_place']"

    patch workspace_memory_url(@workspace, @memory),
      params: {edit_base: "stale", save_as: "in_place", memory: {title: "T", content: "mine"}}

    assert_response :unprocessable_entity
    assert_select "button[name='save_as'][value='in_place']", count: 0
    assert_select "button[name='save_as'][value='new_version']"
    assert_match "Press Save as new version", response.body
  end

  test "a form refused for changing nothing doesn't claim to hold unsaved work" do
    sign_in_as(users(:one))
    @memory.reload

    patch workspace_memory_url(@workspace, @memory),
      params: {save_as: "new_version", memory: {title: "T", content: "first"}}

    assert_response :unprocessable_entity
    assert_select "form[data-memory-editor-start-dirty-value='false']"
  end

  test "a form refused for another reason still does" do
    sign_in_as(users(:one))

    patch workspace_memory_url(@workspace, @memory),
      params: {save_as: "new_version", memory: {title: "T", content: ""}}

    assert_select "form[data-memory-editor-start-dirty-value='true']"
  end

  # --- banners ----------------------------------------------------------------------

  test "the archived and deleted banners don't promise a member what they can't do" do
    sign_in_as(users(:member))

    get archived_workspaces_url
    assert_no_match(/You can unarchive/, response.body)
    assert_match ERB::Util.html_escape(I18n.t("workspaces.archives.index.alert_description")), response.body

    get deleted_workspaces_url
    assert_match ERB::Util.html_escape(I18n.t("workspaces.deleted.index.alert_description")), response.body
  end
end
