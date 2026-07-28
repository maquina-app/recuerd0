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

  test "onboarding state matrix keeps connection paths, content, and dismissal independent" do
    [false, true].repeated_permutation(4).each_with_index do |(manual, oauth, content, dismissed), index|
      user = Account.create_with_user(
        email_address: "onboarding-matrix-#{index}@example.com",
        password: "password",
        password_confirmation: "password"
      )
      workspace = user.account.workspaces.find_by!(name: "My Workspace")
      manual_token = user.access_tokens.create!(permission: "full_access")
      oauth_token = create_oauth_token(user:, suffix: index)
      manual_token.touch_last_used! if manual
      oauth_token.touch_last_used! if oauth
      if content
        Memory.create_with_content(
          workspace,
          title: "Matrix content",
          content: "Body",
          source: "manual"
        )
      end
      user.update!(onboarding_dismissed_at: Time.current) if dismissed

      Current.user = user
      clear_onboarding_memoization

      label = "manual=#{manual}, oauth=#{oauth}, content=#{content}, dismissed=#{dismissed}"
      agent_connected = manual || oauth
      completed_count = [agent_connected, content].count(true)

      assert_equal agent_connected, onboarding_agent_connected?, label
      assert_equal manual, onboarding_terminal_connected?, label
      assert_equal oauth, onboarding_chat_connected?, label
      assert_equal content, onboarding_first_content?, label
      assert_equal completed_count, onboarding_completed_count, label
      assert_equal 2, onboarding_total_steps, label
      assert_equal(!dismissed && completed_count < 2, show_onboarding_alert?, label)
    end
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

  def create_oauth_token(user: @user, suffix: "default")
    client = OauthClient.create!(
      client_name: "Onboarding helper client #{suffix}",
      redirect_uris: ["https://example.com/callback"].to_json
    )
    user.access_tokens.create!(
      permission: "read_only",
      oauth_client: client,
      expires_at: 1.hour.from_now
    )
  end

  def clear_onboarding_memoization
    %i[
      @onboarding_agent_connected
      @onboarding_terminal_connected
      @onboarding_chat_connected
      @onboarding_first_content
    ].each do |variable|
      remove_instance_variable(variable) if instance_variable_defined?(variable)
    end
  end
end
