require "test_helper"

class OauthAuthorizationCodeTest < ActiveSupport::TestCase
  # RFC 7636 Appendix B test vector
  PKCE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk".freeze
  PKCE_CHALLENGE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM".freeze

  setup do
    @client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))
    @user = users(:one)
  end

  def build_code(challenge: PKCE_CHALLENGE, expires_at: 10.minutes.from_now)
    @client.oauth_authorization_codes.create!(
      user: @user,
      code: SecureRandom.urlsafe_base64(32),
      code_challenge: challenge,
      code_challenge_method: "S256",
      redirect_uri: "https://claude.ai/cb",
      scope: "memories:read",
      expires_at: expires_at
    )
  end

  test "pkce_valid? accepts the matching verifier" do
    assert build_code.pkce_valid?(PKCE_VERIFIER)
  end

  test "pkce_valid? rejects a wrong verifier" do
    assert_not build_code.pkce_valid?("wrong-verifier")
  end

  test "pkce_valid? rejects nil verifier" do
    assert_not build_code.pkce_valid?(nil)
  end

  test "expired? reflects expires_at" do
    assert_not build_code.expired?
    assert build_code(expires_at: 1.minute.ago).expired?
  end

  test "active scope excludes expired codes" do
    fresh = build_code
    build_code(expires_at: 1.minute.ago)

    assert_equal [fresh], OauthAuthorizationCode.active.to_a
  end
end
