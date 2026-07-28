module OnboardingHelper
  def onboarding_agent_connected?
    return @onboarding_agent_connected if defined?(@onboarding_agent_connected)

    @onboarding_agent_connected = Current.user.access_tokens
      .where.not(last_used_at: nil)
      .exists?
  end

  def onboarding_first_content?
    return @onboarding_first_content if defined?(@onboarding_first_content)

    # Memories belong to an account through their workspace and do not have a
    # user_id, so first content is intentionally account-wide.
    @onboarding_first_content = Current.user.account.workspaces
      .joins(:memories)
      .where(memories: {parent_memory_id: nil})
      .where("memories.source IS NULL OR memories.source != ?", "system")
      .exists?
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
