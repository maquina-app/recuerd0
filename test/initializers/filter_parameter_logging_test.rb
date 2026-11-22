require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  setup do
    @filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  end

  test "the OAuth authorization code and PKCE verifier are filtered" do
    filtered = @filter.filter("grant_type" => "authorization_code", "code" => "abc", "code_verifier" => "xyz")

    assert_equal "[FILTERED]", filtered["code"]
    assert_equal "[FILTERED]", filtered["code_verifier"]
    assert_equal "authorization_code", filtered["grant_type"]
  end

  test "names that only contain code are left alone" do
    filtered = @filter.filter("code_challenge_method" => "S256", "content" => "notes")

    assert_equal "S256", filtered["code_challenge_method"]
    assert_equal "notes", filtered["content"]
  end
end
