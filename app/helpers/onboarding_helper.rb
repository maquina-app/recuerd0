module OnboardingHelper
  def onboarding_agent_connected?
    return @onboarding_agent_connected if defined?(@onboarding_agent_connected)

    @onboarding_agent_connected = Current.user.access_tokens
      .where.not(last_used_at: nil)
      .exists?
  end

  def onboarding_terminal_connected?
    return @onboarding_terminal_connected if defined?(@onboarding_terminal_connected)

    @onboarding_terminal_connected = Current.user.access_tokens.manual
      .where.not(last_used_at: nil)
      .exists?
  end

  def onboarding_chat_connected?
    return @onboarding_chat_connected if defined?(@onboarding_chat_connected)

    @onboarding_chat_connected = Current.user.access_tokens.oauth
      .where.not(last_used_at: nil)
      .exists?
  end

  def onboarding_first_content?
    return @onboarding_first_content if defined?(@onboarding_first_content)

    # Per person now that memories record a creator, so a teammate is not told
    # they are halfway through because a colleague saved something. A memory with
    # no recorded creator belongs to the account admin.
    creators = Current.user.admin? ? [nil, Current.user.id] : [Current.user.id]

    @onboarding_first_content = Current.user.account.workspaces
      .joins(:memories)
      .where(memories: {parent_memory_id: nil, created_by_id: creators})
      .where("memories.source IS NULL OR memories.source != ?", "system")
      .exists?
  end

  HOSTED_INSTANCE = "recuerd0.ai"

  # The CLI already defaults to the hosted service, so --api-url only appears on
  # an instance that needs it, carrying that instance's real address.
  def cli_account_add_command(token: "<token>")
    api_url = (" --api-url #{request.base_url}" unless request.host == HOSTED_INSTANCE)

    "recuerd0 account add personal#{api_url} --token #{token}"
  end

  # The workspace being looked at, or the account's first, so a command copied
  # from the drawer runs as it is.
  def onboarding_workspace_id
    @workspace&.id || Current.account.workspaces.active.order(:created_at).pick(:id) || "<id>"
  end

  def onboarding_completed_count
    [onboarding_agent_connected?, onboarding_first_content?].count(true)
  end

  def onboarding_total_steps
    2
  end

  def show_onboarding_alert?
    Current.user.onboarding_dismissed_at.nil? &&
      onboarding_completed_count < onboarding_total_steps
  end
end
