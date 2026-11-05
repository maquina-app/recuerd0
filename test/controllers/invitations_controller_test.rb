require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @token = @account.generate_invitation_token
  end

  test "show renders registration form for valid token" do
    get invitation_url(token: @token)
    assert_response :success
  end

  test "show renders error for expired token" do
    travel 8.days do
      get invitation_url(token: @token)
      assert_response :unprocessable_entity
    end
  end

  test "show renders error for invalid token" do
    get invitation_url(token: "invalid-garbage")
    assert_response :unprocessable_entity
  end

  test "create registers user under invited account" do
    workspace = @account.workspaces.create!(name: "Invitation defaults")
    starter_map = workspace.memories.find_by!(title: WorkspaceStarter::TITLE)
    defaults = 2.times.map do |index|
      Memory.create_with_content(
        workspace,
        title: "Default #{index}",
        content: "Body #{index}",
        default_pinned: true
      )
    end

    assert_difference("@account.users.count") do
      post invitations_url, params: {
        token: @token,
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    new_user = User.find_by(email_address: "newuser@example.com")
    assert_not_nil new_user
    assert_equal @account, new_user.account
    assert new_user.member?
    assert_equal [starter_map.id, *defaults.map(&:id)],
      new_user.pins.for_memories.order(:pinnable_id).pluck(:pinnable_id)
    assert_redirected_to workspaces_path
  end

  test "create fails with invalid params" do
    assert_no_difference("User.count") do
      post invitations_url, params: {
        token: @token,
        user: {
          email_address: "",
          password: "short",
          password_confirmation: "mismatch"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create succeeds at any user count in single-tenant mode" do
    8.times do |i|
      @account.users.create!(
        email_address: "single#{i}@example.com",
        password: "password",
        role: "member"
      )
    end

    original = Rails.application.config.multi_tenant
    Rails.application.config.multi_tenant = false

    assert_difference("@account.users.count") do
      post invitations_url, params: {
        token: @token,
        user: {
          email_address: "unlimited@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to workspaces_path
  ensure
    Rails.application.config.multi_tenant = original
  end

  test "create fails when account at limit in multi-tenant mode" do
    8.times do |i|
      @account.users.create!(
        email_address: "fill#{i}@example.com",
        password: "password",
        role: "member"
      )
    end
    assert @account.at_user_limit?

    assert_no_difference("User.count") do
      post invitations_url, params: {
        token: @token,
        user: {
          email_address: "blocked@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with expired token" do
    travel 8.days do
      assert_no_difference("User.count") do
        post invitations_url, params: {
          token: @token,
          user: {
            email_address: "late@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end

      assert_response :unprocessable_entity
    end
  end

  # U-01
  test "an email that already has an account gets an inline error, not a crash" do
    assert_no_difference("User.count") do
      post invitations_url, params: {token: @token, user: {email_address: users(:two).email_address, password: "password123", password_confirmation: "password123"}}
    end

    assert_response :unprocessable_entity
    assert_select "[data-form-part='error']", text: /#{I18n.t("invitations.show.email_taken")}/
    assert_select "[data-form-part='error'] a[href=?]", new_session_path
  end

  test "losing a race for the same email is handled too" do
    @account.users.create!(email_address: "racer@example.com", password: "password123", password_confirmation: "password123", role: "member")
    User.class_eval { alias_method :__valid, :valid? }
    User.define_method(:valid?) { |*| true }

    assert_no_difference("User.count") do
      post invitations_url, params: {token: @token, user: {email_address: "racer@example.com", password: "password123", password_confirmation: "password123"}}
    end
    assert_response :unprocessable_entity
  ensure
    User.class_eval do
      alias_method :valid?, :__valid
      remove_method :__valid
    end
  end

  test "a signed-in visitor is told why a second account needs another email" do
    sign_in_as(users(:two))

    get invitation_url(token: @token)

    assert_match users(:two).email_address, response.body
  end

  # U-20
  test "an admin can revoke every link" do
    sign_in_as(users(:one))

    delete account_invitation_url

    assert_redirected_to account_path
    delete session_url
    get invitation_url(token: @token)
    assert_response :unprocessable_entity
  end

  test "a member cannot revoke links" do
    sign_in_as(users(:member))

    delete account_invitation_url

    assert_equal 0, @account.reload.invitation_generation
  end

  # U-22
  test "an account never named reads as its owner's team, and the legal line shows" do
    @account.update!(name: users(:one).email_address.split("@").first)

    get invitation_url(token: @token)

    assert_select "[data-card-part='title'], h3, h2", text: /#{users(:one).email_address}/
    assert_match I18n.t("invitations.show.description"), response.body
    assert_no_match(/join this workspace/, response.body)
    assert_select "a[href=?]", terms_path
    assert_select "a[href=?]", privacy_path
  end

  test "a chosen account name is used as it is" do
    @account.update!(name: "Maquina")

    get invitation_url(token: @token)

    assert_match "Join Maquina", response.body
  end
end
