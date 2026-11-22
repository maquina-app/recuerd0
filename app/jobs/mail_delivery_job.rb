# Delivers every ApplicationMailer email, retrying the provider's rate limit.
#
# The SMTP provider allows two sends a second and refuses a burst with
# `550 Too many requests`: a permanent code for a temporary condition, so Action
# Mailer's job gave up at once. Onboarding emails for a day's signups come due
# together, and in March 2026 fifteen of them were lost that way. A 550 for
# anything else, a mailbox that doesn't exist, still fails at once.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  class RateLimited < StandardError; end

  retry_on RateLimited, Net::SMTPServerBusy, wait: :polynomially_longer, attempts: 5

  def perform(...)
    super
  rescue Net::SMTPFatalError => error
    raise unless error.message.include?("Too many requests")

    raise RateLimited, error.message
  end
end
