class ProfileMailerPreview < ActionMailer::Preview
  def password_changed
    ProfileMailer.password_changed(User.take)
  end
end
