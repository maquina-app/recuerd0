# Preview all emails at http://localhost:3000/rails/mailers/registrations_mailer
class RegistrationsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/registrations_mailer/welcome
  def welcome
    RegistrationsMailer.welcome(User.take)
  end
end
