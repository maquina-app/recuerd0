module AuthenticationHelper
  def sign_in_as(user)
    post session_url, params: {email_address: user.email_address, password: "password"}
  end
end
