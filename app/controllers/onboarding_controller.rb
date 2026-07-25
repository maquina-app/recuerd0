class OnboardingController < ApplicationController
  def dismiss
    Current.user.update!(onboarding_dismissed_at: Time.current)
    redirect_back fallback_location: workspaces_path, status: :see_other
  end
end
