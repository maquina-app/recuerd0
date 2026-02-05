require "test_helper"

class Profile::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "update changes password with valid current password" do
    sign_in_as(@user)
    patch profile_password_url, params: {
      current_password: "password",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to profile_path
    assert @user.reload.authenticate("newpassword123")
  end

  test "update rejects incorrect current password" do
    sign_in_as(@user)
    patch profile_password_url, params: {
      current_password: "wrongpassword",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to profile_path
    assert_equal I18n.t("profile.passwords.update.current_password_invalid"), flash[:alert]
    assert @user.reload.authenticate("password")
  end

  test "update rejects mismatched confirmation" do
    sign_in_as(@user)
    patch profile_password_url, params: {
      current_password: "password",
      password: "newpassword123",
      password_confirmation: "differentpassword"
    }

    assert_redirected_to profile_path
    assert @user.reload.authenticate("password")
  end

  test "update sends notification email" do
    sign_in_as(@user)

    assert_enqueued_email_with ProfileMailer, :password_changed, args: [@user] do
      patch profile_password_url, params: {
        current_password: "password",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    end
  end

  test "unauthenticated access redirects to login" do
    patch profile_password_url, params: {
      current_password: "password",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to new_session_url
  end
end
