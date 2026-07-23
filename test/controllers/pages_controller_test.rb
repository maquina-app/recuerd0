require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET terms renders terms of service without authentication" do
    get terms_url
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "GET privacy renders privacy policy without authentication" do
    get privacy_url
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "GET pricing renders pricing page without authentication" do
    get pricing_url
    assert_response :success
  end

  test "GET license renders license page without authentication" do
    get license_url
    assert_response :success
    assert_select "h1", "License"
  end

  test "GET api docs distinguishes raw REST search from MCP and workspace search" do
    get api_docs_url

    assert_response :success
    assert_select "#search h3", text: "REST Search Memories"
    assert_includes response.body, "release notes"
    assert_includes response.body, "raw multi-term FTS5 query"
    assert_select "a[href='/mcp#memory-search']"
  end

  test "GET MCP docs renders the safe phrase and exact-tag search contract" do
    get mcp_url

    assert_response :success
    assert_select "#memory-search h3", text: "Memory search"
    assert_includes response.body, "case-insensitive whole-tag equality"
    assert_includes response.body, "Queries under three characters"
    assert_includes response.body, "relevance"
    assert_select "a[href='/api-docs#search']"
  end
end
