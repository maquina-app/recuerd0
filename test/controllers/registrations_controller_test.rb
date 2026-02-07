require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders registration form" do
    get new_registration_url
    assert_response :success
    assert_select "h2", "Create an account"
    assert_select "input[name='user[email_address]']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "POST create with valid params creates account and user" do
    assert_difference ["Account.count", "User.count"], 1 do
      post registration_url, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    user = User.find_by(email_address: "newuser@example.com")
    assert user.present?
    assert user.account.present?
    assert_equal "newuser", user.account.name
    assert_redirected_to workspaces_path
  end

  test "POST create auto-logs in user" do
    post registration_url, params: {
      user: {
        email_address: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert cookies[:session_id].present?
    user = User.find_by(email_address: "newuser@example.com")
    assert_equal 1, user.sessions.count
  end

  test "POST create seeds Start Here workspace with memories" do
    post registration_url, params: {
      user: {
        email_address: "seedtest@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    user = User.find_by(email_address: "seedtest@example.com")
    workspace = user.account.workspaces.find_by(name: "Start Here")
    assert workspace.present?, "Expected 'Start Here' workspace after registration"
    assert_equal 5, workspace.memories.count
  end

  test "POST create with invalid params does not create workspace" do
    assert_no_difference "Workspace.count" do
      post registration_url, params: {
        user: {
          email_address: "seedtest@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end
  end

  test "POST create with invalid params re-renders form with errors" do
    assert_no_difference ["Account.count", "User.count"] do
      post registration_url, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".text-destructive"
  end

  test "POST create with existing email shows error" do
    existing_user = users(:one)

    assert_no_difference ["Account.count", "User.count"] do
      post registration_url, params: {
        user: {
          email_address: existing_user.email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
