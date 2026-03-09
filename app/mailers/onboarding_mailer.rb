class OnboardingMailer < ApplicationMailer
  before_action :attach_onboarding_icons

  def api_token(user)
    @user = user
    return if skip_delivery?(user)
    return if user.access_tokens.any?

    mail subject: default_i18n_subject, to: user.email_address
  end

  def cli_setup(user)
    @user = user
    return if skip_delivery?(user)

    mail subject: default_i18n_subject, to: user.email_address
  end

  def ai_integration(user)
    @user = user
    return if skip_delivery?(user)

    mail subject: default_i18n_subject, to: user.email_address
  end

  def check_in(user)
    @user = user
    return if skip_delivery?(user)

    @workspaces_count = user.account.workspaces.active.count
    @memories_count = user.account.workspaces.active.sum(:memories_count)
    @has_api_token = user.access_tokens.any?

    mail subject: default_i18n_subject, to: user.email_address
  end

  def advanced_tips(user)
    @user = user
    return if skip_delivery?(user)

    user_workspaces = user.account.workspaces.active
    return if user_workspaces.count <= 1 && user_workspaces.first&.name == "Start Here"

    mail subject: default_i18n_subject, to: user.email_address
  end

  private

  def skip_delivery?(user)
    user.anonymized?
  end

  def attach_onboarding_icons
    %w[onboarding-api onboarding-cli onboarding-agent onboarding-checkin onboarding-search].each do |icon|
      attachments.inline["#{icon}.png"] = Rails.root.join("app/assets/images/#{icon}.png").read
    end
  end
end
