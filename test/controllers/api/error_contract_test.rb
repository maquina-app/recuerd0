require "test_helper"

# "All errors follow a consistent JSON structure": what the API answers when the
# request is wrong, and what each error's body looks like.
class ApiErrorContractTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @headers = auth_headers("test_full_token_456").merge("Content-Type" => "application/json")
  end

  # Bad input: every one of these was a 500

  test "an invalid page is a 422 on every paginated endpoint" do
    paths = [
      workspaces_url(format: :json),
      workspace_memories_url(@workspace, format: :json),
      browse_memories_url(format: :json),
      search_url(format: :json, q: "memory")
    ]

    paths.product(%w[0 -1 abc]).each do |path, page|
      get path, params: {page: page}, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", "#{path}?page=#{page}"
    end
  end

  test "an object sent as a bare string is a 422" do
    {
      workspaces_url(format: :json) => {workspace: "x"},
      workspace_memories_url(@workspace, format: :json) => {memory: "x"},
      workspace_memory_versions_url(@workspace, @memory, format: :json) => {version: "x"}
    }.each do |path, body|
      post path, params: body.to_json, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", path
    end
  end

  test "a null character is a 422 and saves nothing" do
    assert_no_difference ["Memory.count", "Workspace.count"] do
      post workspace_memories_url(@workspace, format: :json),
        params: {memory: {title: "a\u0000b", content: "x"}}.to_json, headers: @headers
      assert_json_error :unprocessable_entity, "VALIDATION_ERROR"

      post workspace_memories_url(@workspace, format: :json),
        params: {memory: {title: "a", content: "x\u0000y"}}.to_json, headers: @headers
      assert_json_error :unprocessable_entity, "VALIDATION_ERROR"

      post workspaces_url(format: :json),
        params: {workspace: {name: "a\u0000b"}}.to_json, headers: @headers
      assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
    end
  end

  test "a line_start anywhere past the end is an empty body" do
    memory = Memory.create_with_content(@workspace, title: "Lines", content: "1\n2\n3\n4\n5\n6")

    [7, 100].each do |line_start|
      get workspace_memory_url(@workspace, memory, format: :json), params: {line_start: line_start}, headers: @headers

      assert_response :success
      content = response.parsed_body["content"]
      assert_equal "", content["body"]
      assert_equal 6, content["total_lines"]
      assert_equal 7, content["line_start"]
      assert_equal 6, content["line_end"]
    end
  end

  test "a line number that isn't a positive integer is a 422" do
    memory = Memory.create_with_content(@workspace, title: "Lines", content: "1\n2\n3")

    [{line_start: "abc"}, {line_start: 0}, {line_start: -1}, {line_end: 0}, {line_end: "x"}, {line_start: "9" * 25}].each do |line_params|
      get workspace_memory_url(@workspace, memory, format: :json), params: line_params, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", line_params.inspect
    end
  end

  test "a page that can't be read is a 422 however it is written" do
    ["1.5", "1e3", "9223372036854775807", "100000000000000000000", "", " "].each do |page|
      get workspaces_url(format: :json), params: {page: page}, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", page
    end

    get workspaces_url(format: :json), params: {page: "99999999999"}, headers: @headers
    assert_response :success
    assert_empty response.parsed_body
  end

  test "a query parameter sent as a list or an object is a 422" do
    memory_url = workspace_memory_url(@workspace, @memory, format: :json)
    memories_url = workspace_memories_url(@workspace, format: :json)

    [
      "#{workspaces_url(format: :json)}?page[]=1",
      "#{memories_url}?page[]=1",
      "#{search_url(format: :json)}?q=memory&page[]=1",
      "#{search_url(format: :json)}?q[]=abc",
      "#{memories_url}?per_page[]=1",
      "#{memories_url}?tags[]=x",
      "#{memories_url}?title[]=x",
      "#{memories_url}?tags[a]=x",
      "#{memory_url}?line_start[]=1",
      "#{memory_url}?line_end[]=1",
      "#{memory_url}?line_start[a]=1",
      "#{workspace_merge_candidates_url(@workspace, format: :json)}?min_score[]=1"
    ].each do |url|
      get url, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", url
    end
  end

  test "a min_score that isn't a number is a 422 rather than the lowest score" do
    get workspace_merge_candidates_url(@workspace, format: :json), params: {min_score: "abc"}, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"

    get workspace_merge_candidates_url(@workspace, format: :json), params: {min_score: "0.5"}, headers: @headers
    assert_response :success
  end

  test "a query string that isn't valid UTF-8 is a JSON 400" do
    get "#{search_url(format: :json)}?q=abc%FFdef", headers: @headers
    assert_json_error :bad_request, "BAD_REQUEST"

    get "#{workspaces_url(format: :json)}?q=abc%FFdef"
    assert_json_error :bad_request, "BAD_REQUEST"
  end

  test "a browser sending a query string that isn't valid UTF-8 gets the 400 page" do
    get "#{search_url}?q=abc%FFdef"

    assert_response :bad_request
    assert_equal "text/html", response.media_type
    assert_not_includes response.body, "Exception caught"
  end

  test "an unknown sort or direction is a 422 on the memory lists" do
    [workspace_memories_url(@workspace, format: :json), browse_memories_url(format: :json)].each do |url|
      get url, params: {sort: "nope"}, headers: @headers
      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", url

      get url, params: {direction: "nope"}, headers: @headers
      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", url

      get url, params: {sort: "title", direction: "asc"}, headers: @headers
      assert_response :success
    end
  end

  test "a link target that isn't one id is a 422" do
    memory = Memory.create_with_content(@workspace, title: "From", content: "b")

    [[1], {a: 1}, true, 1.5].each do |value|
      assert_no_difference "MemoryLink.count", value.inspect do
        post workspace_memory_links_url(@workspace, memory, format: :json),
          params: {to_memory_id: value}.to_json, headers: @headers
      end

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", value.inspect
    end

    post workspace_memory_links_url(@workspace, memory, format: :json),
      params: {link: "x"}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  test "a workspace field of the wrong shape is a 422 naming it" do
    {"name" => [%w[a], {a: 1}, 5], "description" => [%w[a], {a: 1}, 5]}.each do |field, values|
      values.each do |value|
        assert_no_difference "Workspace.count", "#{field}: #{value.inspect}" do
          post workspaces_url(format: :json),
            params: {workspace: {"name" => "Named"}.merge(field => value)}.to_json, headers: @headers
        end

        assert_json_error :unprocessable_entity, "VALIDATION_ERROR", "#{field}: #{value.inspect}"
        assert response.parsed_body.dig("error", "details").key?(field), "#{field}: #{value.inspect}"
      end
    end

    patch workspace_url(@workspace, format: :json),
      params: {workspace: {description: %w[a]}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  # Errors that came back as HTML

  test "a body of the wrong shape answers in JSON" do
    [
      "",
      {workspace: {}}.to_json,
      [1, 2].to_json
    ].each do |body|
      post workspaces_url(format: :json), params: body, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", body
      assert_includes response.parsed_body.dig("error", "message"), "workspace"
    end
  end

  test "an empty memory object is a 422, on create and update" do
    post workspace_memories_url(@workspace, format: :json), params: {memory: {}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"

    patch workspace_memory_url(@workspace, @memory, format: :json), params: {memory: {}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  test "JSON sent as text/plain answers in JSON" do
    post workspaces_url(format: :json), params: {workspace: {name: "x"}}.to_json,
      headers: @headers.merge("Content-Type" => "text/plain")

    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  test "malformed JSON is a BAD_REQUEST in JSON" do
    post workspaces_url(format: :json), params: "{nope", headers: @headers

    assert_json_error :bad_request, "BAD_REQUEST"
  end

  test "an unknown API path is a NOT_FOUND in JSON, whatever the verb" do
    %i[get post patch delete].each do |verb|
      send(verb, "/nope.json", headers: @headers)

      assert_json_error :not_found, "NOT_FOUND", verb
    end

    get "/nope", headers: {"Accept" => "application/json"}
    assert_json_error :not_found, "NOT_FOUND"
  end

  test "an action with no JSON representation is a NOT_ACCEPTABLE in JSON" do
    get new_workspace_url(format: :json), headers: @headers

    assert_json_error :not_acceptable, "NOT_ACCEPTABLE"
  end

  test "the exceptions app answers an API path in JSON even when the format is gone" do
    %w[400 404 422 500].each do |status|
      env = Rack::MockRequest.env_for("/#{status}", "action_dispatch.original_path" => "/workspaces.json")
      code, headers, body = Rails.application.routes.call(env)

      assert_equal status.to_i, code
      assert_match %r{application/json}, headers["content-type"]
      assert_equal status.to_i, JSON.parse(body.each.to_a.join).dig("error", "status")
    end
  end

  test "the exceptions app still serves a browser its HTML page" do
    env = Rack::MockRequest.env_for("/500", "action_dispatch.original_path" => "/workspaces", "HTTP_ACCEPT" => "text/html")
    code, headers, = Rails.application.routes.call(env)

    assert_equal 500, code
    assert_match %r{text/html}, headers["content-type"]
  end

  test "browsers still get the HTML route for an unknown path" do
    sign_in_as users(:one)

    get "/nope", headers: {"Accept" => "text/html"}

    assert_response :not_found
    assert_equal "text/html", response.media_type
  end

  # Wrongly shaped fields

  test "a field of the wrong shape is a 422 naming it, and saves nothing" do
    {
      "tags" => ["one,two", [nil, 1, "", {a: 1}], [1]],
      "content" => [%w[a b], {body: "x"}, 5],
      "title" => [%w[a]],
      "source" => [{a: 1}]
    }.each do |field, values|
      values.each do |value|
        assert_no_difference "Memory.count", "#{field}: #{value.inspect}" do
          post workspace_memories_url(@workspace, format: :json),
            params: {memory: {"title" => "t", "content" => "b"}.merge(field => value)}.to_json, headers: @headers
        end

        assert_json_error :unprocessable_entity, "VALIDATION_ERROR", "#{field}: #{value.inspect}"
        assert response.parsed_body.dig("error", "details").key?(field), "#{field}: #{value.inspect}"
      end
    end
  end

  test "new versions and updates refuse wrongly shaped fields too" do
    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {version: {content: %w[a b]}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"

    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {version: {content: "changed", change_note: %w[a b]}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
    assert response.parsed_body.dig("error", "details").key?("change_note")

    patch workspace_memory_url(@workspace, @memory, format: :json),
      params: {memory: {tags: "one,two"}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  test "a flat body keeps its content" do
    post workspace_memories_url(@workspace, format: :json),
      params: {title: "Flat", content: "kept"}.to_json, headers: @headers

    assert_response :created
    assert_equal "kept", response.parsed_body.dig("content", "body")
  end

  # Size limits

  test "values past the documented limits are refused" do
    {
      "tags" => Array.new(Memory::MAX_TAGS + 1) { |n| "tag#{n}" },
      "source" => "s" * (Memory::MAX_SOURCE_LENGTH + 1)
    }.each do |field, value|
      post workspace_memories_url(@workspace, format: :json),
        params: {memory: {:title => "t", :content => "b", field => value}}.to_json, headers: @headers

      assert_json_error :unprocessable_entity, "VALIDATION_ERROR", field
    end

    post workspace_memories_url(@workspace, format: :json),
      params: {memory: {title: "t", tags: ["t" * (Memory::MAX_TAG_LENGTH + 1)]}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  test "a body past the limit is refused on create, update and new version" do
    body = "x" * (Memory::MAX_CONTENT_BYTES + 1)

    post workspace_memories_url(@workspace, format: :json),
      params: {memory: {title: "t", content: body}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
    assert_equal ["content"], response.parsed_body.dig("error", "details").keys

    patch workspace_memory_url(@workspace, @memory, format: :json),
      params: {memory: {content: body}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"

    post workspace_memory_versions_url(@workspace, @memory, format: :json),
      params: {version: {content: body}}.to_json, headers: @headers
    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
  end

  test "a row already past a limit can still be edited in other ways" do
    memory = Memory.create_with_content(@workspace, title: "Old", content: "b")
    memory.update_columns(source: "s" * (Memory::MAX_SOURCE_LENGTH + 1))

    patch workspace_memory_url(@workspace, memory, format: :json),
      params: {memory: {title: "New"}}.to_json, headers: @headers

    assert_response :success
  end

  # Search

  test "a query over the limit is a 422 rather than quietly cut" do
    get search_url(format: :json, q: "a" * 101), headers: @headers

    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
    assert_includes response.parsed_body.dig("error", "message"), "100"
  end

  test "a query at the limit still runs" do
    get search_url(format: :json, q: "a" * 100), headers: @headers

    assert_response :success
  end

  # Messages

  test "validation messages read as one clean sentence" do
    post workspaces_url(format: :json), params: {workspace: {name: ""}}.to_json, headers: @headers
    assert_equal "Give your workspace a name so you can find it later.", response.parsed_body.dig("error", "message")

    post workspaces_url(format: :json), params: {workspace: {name: "x", description: "y" * 501}}.to_json, headers: @headers
    assert_equal "Description is too long (maximum is 500 characters).", response.parsed_body.dig("error", "message")

    post workspace_memories_url(@workspace, format: :json), params: {memory: {title: "x" * 256}}.to_json, headers: @headers
    assert_equal "Title is too long (maximum is 255 characters).", response.parsed_body.dig("error", "message")
  end

  test "a duplicate link says so" do
    a = Memory.create_with_content(@workspace, title: "A", content: "b")
    b = Memory.create_with_content(@workspace, title: "B", content: "b")
    MemoryLink.create!(from_memory: a, to_memory: b)

    post workspace_memory_links_url(@workspace, a, format: :json), params: {to_memory_id: b.id}.to_json, headers: @headers

    assert_json_error :unprocessable_entity, "VALIDATION_ERROR"
    assert_equal "These memories are already linked.", response.parsed_body.dig("error", "message")
  end

  # Auth and headers

  test "the Bearer scheme is case-insensitive" do
    %w[bearer BEARER Bearer].each do |scheme|
      get workspaces_url(format: :json), headers: {"Authorization" => "#{scheme} test_full_token_456"}

      assert_response :success, scheme
    end
  end

  test "a 201 says where the new resource lives" do
    post workspaces_url(format: :json), params: {workspace: {name: "New"}}.to_json, headers: @headers
    assert_response :created
    assert_equal response.parsed_body["url"], response.headers["Location"]

    post workspace_memories_url(@workspace, format: :json), params: {memory: {title: "New", content: "b"}}.to_json, headers: @headers
    assert_response :created
    assert_equal response.parsed_body["url"], response.headers["Location"]
    memory_id = response.parsed_body["id"]

    post workspace_memory_versions_url(@workspace, memory_id, format: :json), params: {version: {content: "v2"}}.to_json, headers: @headers
    assert_response :created
    assert_equal response.parsed_body["url"], response.headers["Location"]
  end

  private

  def assert_json_error(status, code, context = nil)
    assert_response status, context
    assert_equal "application/json", response.media_type, context
    error = response.parsed_body["error"]
    assert_equal code, error["code"], context
    assert_equal Rack::Utils.status_code(status), error["status"], context
    assert error["message"].present?, context
  end
end
