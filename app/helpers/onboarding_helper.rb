module OnboardingHelper
  def onboarding_token_created?
    Current.user.account.users.joins(:access_tokens).exists?
  end

  def onboarding_cli_connected?
    Current.user.account.users
      .joins(:access_tokens)
      .where.not(access_tokens: {last_used_at: nil})
      .exists?
  end

  def onboarding_first_content?
    Current.user.account.workspaces
      .joins(:memories)
      .where(memories: {parent_memory_id: nil})
      .where("memories.source IS NULL OR memories.source != ?", "system")
      .exists?
  end

  def show_onboarding_banner?
    Current.user.onboarding_dismissed_at.nil? && !onboarding_first_content?
  end
end
