# Preview all emails at http://localhost:3820/rails/mailers/onboarding_mailer
class OnboardingMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3820/rails/mailers/onboarding_mailer/api_token
  def api_token
    OnboardingMailer.api_token(User.take)
  end

  # Preview this email at http://localhost:3820/rails/mailers/onboarding_mailer/cli_setup
  def cli_setup
    OnboardingMailer.cli_setup(User.take)
  end

  # Preview this email at http://localhost:3820/rails/mailers/onboarding_mailer/ai_integration
  def ai_integration
    OnboardingMailer.ai_integration(User.take)
  end

  # Preview this email at http://localhost:3820/rails/mailers/onboarding_mailer/check_in
  def check_in
    OnboardingMailer.check_in(User.take)
  end

  # Preview this email at http://localhost:3820/rails/mailers/onboarding_mailer/advanced_tips
  def advanced_tips
    OnboardingMailer.advanced_tips(User.take)
  end
end
