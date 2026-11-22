require "test_helper"

class MailDeliveryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  # Raises what the SMTP provider answers, as the delivery method would.
  class RefusingDelivery
    cattr_accessor :reply

    def initialize(*) = nil

    def deliver!(_mail)
      raise Net::SMTPFatalError.new(Net::SMTP::Response.parse(reply))
    end
  end

  setup do
    ActionMailer::Base.add_delivery_method :refusing, RefusingDelivery
    @delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :refusing
  end

  teardown do
    ActionMailer::Base.delivery_method = @delivery_method
  end

  test "application mail is delivered through this job" do
    assert_enqueued_with(job: MailDeliveryJob) do
      PasswordsMailer.reset(users(:one)).deliver_later
    end
  end

  test "the provider's rate limit is retried later" do
    RefusingDelivery.reply = "550 Too many requests. You can only make 2 requests per second."

    assert_enqueued_with(job: MailDeliveryJob) do
      MailDeliveryJob.perform_now("PasswordsMailer", "reset", "deliver_now", args: [users(:one)])
    end
  end

  test "any other permanent refusal fails at once" do
    RefusingDelivery.reply = "550 Mailbox does not exist"

    assert_raises(Net::SMTPFatalError) do
      MailDeliveryJob.perform_now("PasswordsMailer", "reset", "deliver_now", args: [users(:one)])
    end
    assert_no_enqueued_jobs
  end
end
