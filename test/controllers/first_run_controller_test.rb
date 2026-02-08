require "test_helper"

class FirstRunControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_multi_tenant = Rails.application.config.multi_tenant
    Rails.application.config.multi_tenant = false
  end

  teardown do
    Rails.application.config.multi_tenant = @original_multi_tenant
  end

  test "GET new renders setup form when no accounts exist" do
    delete_all_accounts

    get new_first_run_url
    assert_response :success
    assert_select "h2", I18n.t("first_run.new.heading")
    assert_select "input[name='user[email_address]']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "GET new redirects to root when an account exists" do
    get new_first_run_url
    assert_redirected_to root_path
  end

  test "GET new redirects to root in multi-tenant mode" do
    Rails.application.config.multi_tenant = true
    delete_all_accounts

    get new_first_run_url
    assert_redirected_to root_path
  end

  test "POST create with valid params creates account and user" do
    delete_all_accounts

    assert_difference ["Account.count", "User.count"], 1 do
      post first_run_url, params: {
        user: {
          email_address: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    user = User.find_by(email_address: "admin@example.com")
    assert user.present?
    assert user.account.present?
    assert_equal "admin", user.role
    assert_redirected_to workspaces_path
  end

  test "POST create auto-logs in user" do
    delete_all_accounts

    post first_run_url, params: {
      user: {
        email_address: "admin@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert cookies[:session_id].present?
  end

  test "POST create seeds Start Here workspace" do
    delete_all_accounts

    post first_run_url, params: {
      user: {
        email_address: "admin@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    user = User.find_by(email_address: "admin@example.com")
    workspace = user.account.workspaces.find_by(name: "Start Here")
    assert workspace.present?, "Expected 'Start Here' workspace after first run"
  end

  test "POST create with invalid params re-renders form" do
    delete_all_accounts

    assert_no_difference ["Account.count", "User.count"] do
      post first_run_url, params: {
        user: {
          email_address: "admin@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".text-destructive"
  end

  test "POST create redirects when account already exists" do
    assert_no_difference ["Account.count", "User.count"] do
      post first_run_url, params: {
        user: {
          email_address: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
  end

  test "unauthenticated request redirects to first run when no accounts exist" do
    delete_all_accounts

    get workspaces_url
    assert_redirected_to new_first_run_url
  end

  test "unauthenticated request redirects to login when accounts exist" do
    get workspaces_url
    assert_redirected_to new_session_url
  end

  private

  def delete_all_accounts
    Pin.delete_all
    Content.delete_all
    Memory.delete_all
    Workspace.delete_all
    AccountExport.delete_all
    Session.delete_all
    AccessToken.delete_all
    User.delete_all
    Account.delete_all
  end
end
