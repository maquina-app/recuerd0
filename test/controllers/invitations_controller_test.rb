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
end
