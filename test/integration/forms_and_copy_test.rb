require "test_helper"

class FormsAndCopyTest < ActionDispatch::IntegrationTest
  test "blank memories are refused on web and REST alike" do
    sign_in_as(users(:one))

    assert_no_difference("Memory.count") do
      post workspace_memories_url(workspaces(:one)), params: {memory: {title: "", content: ""}}
    end
    assert_response :unprocessable_entity
    assert_match I18n.t("activerecord.errors.models.memory.attributes.base.blank_memory"), response.body

    assert_no_difference("Memory.count") do
      post workspace_memories_url(workspaces(:one), format: :json),
        params: {memory: {title: ""}},
        headers: auth_headers("test_full_token_456")
    end
    assert_response :unprocessable_entity
  end

  test "the new memory form promises nothing about saving, and no leading heading" do
    sign_in_as(users(:one))

    get new_workspace_memory_url(workspaces(:one))

    assert_select ".save-status", text: ""
    assert_no_match(/memory-editor-saved-label/, response.body)
    assert_no_match(/## a heading/, response.body)
  end

  test "arriving from setup preselects Full Access and suggests a name" do
    sign_in_as(users(:one))

    get profile_url(token_permission: "full_access", token_description: "recuerd0 CLI")

    assert_select "select[name='access_token[permission]'] option[selected][value='full_access']"
    assert_select "input[name='access_token[description]'][value='recuerd0 CLI']"
  end

  test "the token form still defaults to Read Only otherwise" do
    sign_in_as(users(:one))

    get profile_url

    assert_select "select[name='access_token[permission]'] option[selected][value='read_only']"
  end

  test "a blank token description gets a dated name instead of Untitled" do
    sign_in_as(users(:one))

    post profile_access_tokens_url, params: {access_token: {description: " ", permission: "read_only"}}

    assert_match(/\AToken created /, users(:one).access_tokens.order(:created_at).last.description)
  end

  test "profile says what it actually manages and shows the email" do
    sign_in_as(users(:one))

    get profile_url

    assert_no_match(/Manage your name and email/, response.body)
    assert_match users(:one).email_address, response.body
  end

  test "signup states the password rule up front and speaks in sentences" do
    get new_registration_url
    assert_match I18n.t("registrations.new.password_hint"), response.body

    post registration_url, params: {user: {account_name: "Acme", email_address: users(:one).email_address, password: "password123", password_confirmation: "different"}}
    assert_response :unprocessable_entity
    assert_match I18n.t("activerecord.errors.models.user.attributes.password_confirmation.confirmation").gsub("'", "&#39;"), response.body
    assert_no_match(/doesn&#39;t match Password/, response.body)
  end

  test "sign-in wording matches the button" do
    get new_session_url

    assert_no_match(/clicking continue/, response.body)
  end

  test "the palette gets its plural right" do
    sign_in_as(users(:one))
    memory = Memory.create_with_content(workspaces(:one), title: "Zzqx unique title", content: "x")
    memory.rebuild_search_index

    get search_url(q: "Zzqx"), headers: {"Turbo-Frame" => SearchController::PALETTE_FRAME_ID}

    assert_match I18n.t("search.command.see_all", count: 1), response.body
    assert_no_match(/all 1 results/, response.body)
  end

  test "a real source URL is a link, anything else is text, and removed links are plain" do
    sign_in_as(users(:one))
    memory = Memory.create_with_content(workspaces(:one), title: "Links", source: "https://example.com/notes",
      content: "[bad](javascript:alert(1)) and [good](https://example.com)")

    get workspace_memory_url(workspaces(:one), memory)

    assert_select ".src-val a[href='https://example.com/notes'][rel='noopener noreferrer']"
    assert_select ".memory-content a", count: 1
    assert_select ".memory-content a[href='https://example.com']", text: "good"
    assert_match "bad", css_select(".memory-content").text

    memory.update!(source: "javascript:alert(1)")
    get workspace_memory_url(workspaces(:one), memory)
    assert_select ".src-val a", count: 0
  end

  test "workspace rows carry a time for the browser to localize, not a hidden UTC date" do
    sign_in_as(users(:one))

    get workspaces_url

    assert_select "time[data-controller='local-time'][datetime]"
  end
end
