require "test_helper"

class OauthClientTest < ActiveSupport::TestCase
  test "assigns client_id and registered_at on create" do
    client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))

    assert client.client_id.present?
    assert client.registered_at.present?
  end

  test "redirect_uri_list parses the JSON array" do
    client = OauthClient.new(redirect_uris: JSON.generate(%w[https://a.test/cb https://b.test/cb]))

    assert_equal %w[https://a.test/cb https://b.test/cb], client.redirect_uri_list
  end

  test "redirect_uri_list returns empty array on malformed JSON" do
    client = OauthClient.new(redirect_uris: "not json")

    assert_equal [], client.redirect_uri_list
  end

  test "redirect_uri_allowed? checks membership" do
    client = OauthClient.new(redirect_uris: JSON.generate(["https://claude.ai/cb"]))

    assert client.redirect_uri_allowed?("https://claude.ai/cb")
    assert_not client.redirect_uri_allowed?("https://evil.test/cb")
  end

  test "public_client? when no secret" do
    assert OauthClient.new.public_client?
    assert_not OauthClient.new(client_secret_digest: "abc").public_client?
  end

  test "requires client_name and redirect_uris" do
    client = OauthClient.new

    assert_not client.valid?
    assert_includes client.errors.attribute_names, :client_name
    assert_includes client.errors.attribute_names, :redirect_uris
  end

  test "accepts absolute https redirect URIs" do
    client = OauthClient.new(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))

    assert client.valid?
  end

  test "accepts http redirect URI for loopback hosts" do
    client = OauthClient.new(client_name: "Native", redirect_uris: JSON.generate(["http://localhost:1234/cb", "http://127.0.0.1/cb"]))

    assert client.valid?
  end

  test "rejects non-https redirect URI on a remote host" do
    client = OauthClient.new(client_name: "Evil", redirect_uris: JSON.generate(["http://attacker.test/cb"]))

    assert_not client.valid?
    assert_includes client.errors.attribute_names, :redirect_uris
  end

  test "rejects a malformed redirect URI" do
    client = OauthClient.new(client_name: "Bad", redirect_uris: JSON.generate(["::not a uri::"]))

    assert_not client.valid?
    assert_includes client.errors.attribute_names, :redirect_uris
  end
end
