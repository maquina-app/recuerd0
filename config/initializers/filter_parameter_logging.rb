# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# `code` is anchored because it is matched partially: a bare :code would also hide
# any parameter whose name merely contains it. It and `code_verifier` are the OAuth
# authorization code and its PKCE verifier, both posted to /oauth/token.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  /\Acode\z/, :code_verifier
]
