require "test_helper"

class OnboardingHelperTest < ActionView::TestCase
  include OnboardingHelper

  setup do
    @user = Account.create_with_user(
      email_address: "onboarding-helper@example.com",
      password: "password",
      password_confirmation: "password"
    )
    @account = @user.account
    @workspace = @account.workspaces.find_by!(name: "My Workspace")
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "nothing is complete without a used token or user content" do
    assert_not onboarding_agent_connected?
    assert_not onboarding_terminal_connected?
    assert_not onboarding_chat_connected?
    assert_not onboarding_first_content?
    assert_equal 0, onboarding_completed_count
    assert_equal 2, onboarding_total_steps
    assert show_onboarding_alert?
  end

  test "unused manual and OAuth tokens do not connect either path" do
    @user.access_tokens.create!(permission: "full_access")
    create_oauth_token

    assert_not onboarding_agent_connected?
    assert_not onboarding_terminal_connected?
    assert_not onboarding_chat_connected?
  end

  test "a used manual token connects only the Terminal path and the aggregate" do
    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!

    assert onboarding_agent_connected?
    assert onboarding_terminal_connected?
    assert_not onboarding_chat_connected?
  end

  test "a used OAuth token connects only the Chat path and the aggregate" do
    token = create_oauth_token
    token.touch_last_used!

    assert onboarding_agent_connected?
    assert_not onboarding_terminal_connected?
    assert onboarding_chat_connected?
  end

  test "used manual and OAuth tokens connect both paths and the aggregate" do
    manual_token = @user.access_tokens.create!(permission: "full_access")
    oauth_token = create_oauth_token
    manual_token.touch_last_used!
    oauth_token.touch_last_used!

    assert onboarding_agent_connected?
    assert onboarding_terminal_connected?
    assert onboarding_chat_connected?
  end

  test "content is account-wide while agent connection is user-specific" do
    Memory.create_with_content(
      @workspace,
      title: "User content",
      content: "Body",
      source: "manual"
    )
    teammate = @account.users.create!(
      email_address: "onboarding-helper-teammate@example.com",
      password: "password",
      role: "member"
    )
    Current.user = teammate

    assert_not onboarding_agent_connected?
    assert onboarding_first_content?
    assert_equal 1, onboarding_completed_count
    assert show_onboarding_alert?
  end

  test "both signals complete onboarding" do
    token = @user.access_tokens.create!(permission: "full_access")
    token.touch_last_used!
    Memory.create_with_content(
      @workspace,
      title: "User content",
      content: "Body",
      source: nil
    )

    assert_equal 2, onboarding_completed_count
    assert_not show_onboarding_alert?
  end

  test "dismissal hides an incomplete alert" do
    @user.update!(onboarding_dismissed_at: Time.current)

    assert_not show_onboarding_alert?
  end

  test "false predicate results are memoized" do
    assert_queries_count 4 do
      2.times do
        assert_not onboarding_agent_connected?
        assert_not onboarding_terminal_connected?
        assert_not onboarding_chat_connected?
        assert_not onboarding_first_content?
      end
    end
  end

  private

  def create_oauth_token
    client = OauthClient.create!(
      client_name: "Onboarding helper client",
      redirect_uris: ["https://example.com/callback"].to_json
    )
    @user.access_tokens.create!(
      permission: "read_only",
      oauth_client: client,
      expires_at: 1.hour.from_now
    )
  end
end
