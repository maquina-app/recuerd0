require "test_helper"

# A root row keeps v1's title and source. Tags and category follow the current version,
# but these two don't, so anything listing roots has to ask the current version.
class CurrentVersionFieldsTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @headers = auth_headers("test_full_token_456").merge("Content-Type" => "application/json")
    @renamed = Memory.create_with_content(@workspace, title: "Aardvark first name", content: "body", source: "old-source")
    @renamed.create_version!(title: "Zebra current name", source: "new-source", content: "body two")
    @middle = Memory.create_with_content(@workspace, title: "Mongoose steady", content: "other")
  end

  # REST lists

  test "the title filter matches the current title, not v1's" do
    [workspace_memories_url(@workspace, format: :json), browse_memories_url(format: :json)].each do |path|
      get path, params: {title: "Zebra*"}, headers: @headers
      assert_includes root_ids, @renamed.id, path

      get path, params: {title: "Aardvark*"}, headers: @headers
      assert_not_includes root_ids, @renamed.id, path
    end
  end

  test "the source filter matches the current source, not v1's" do
    [workspace_memories_url(@workspace, format: :json), browse_memories_url(format: :json)].each do |path|
      get path, params: {source: "new-source"}, headers: @headers
      assert_includes root_ids, @renamed.id, path

      get path, params: {source: "old-source"}, headers: @headers
      assert_not_includes root_ids, @renamed.id, path
    end
  end

  test "sorting a REST list by title uses the current title" do
    get workspace_memories_url(@workspace, format: :json), params: {sort: "title", direction: "asc", per_page: 100}, headers: @headers

    ids = root_ids
    assert_operator ids.index(@middle.id), :<, ids.index(@renamed.id)
  end

  test "a memory whose purge moved a version into the root still filters on the current title" do
    @renamed.create_version!(title: "Yak newest name", content: "body three")
    @renamed.purge_versions!(keep: 2)

    get workspace_memories_url(@workspace, format: :json), params: {title: "Yak*"}, headers: @headers
    assert_includes root_ids, @renamed.id

    get workspace_memories_url(@workspace, format: :json), params: {title: "Aardvark*"}, headers: @headers
    assert_not_includes root_ids, @renamed.id
  end

  # Sorting anywhere else

  test "ordered_by title uses the current title, and an untitled current version stays untitled" do
    ids = @workspace.memories.latest_versions.where(id: [@renamed.id, @middle.id]).ordered_by("title").map(&:id)
    assert_equal [@middle.id, @renamed.id], ids

    @renamed.current_version.update_column(:title, "")
    ids = @workspace.memories.latest_versions.where(id: [@renamed.id, @middle.id]).ordered_by("title").map(&:id)
    assert_equal [@renamed.id, @middle.id], ids
  end

  test "ordered_by title works on a search" do
    @renamed.rebuild_search_index
    @middle.create_version!(title: "Mongoose body two", content: "body two")
    @middle.rebuild_search_index

    ids = @workspace.memories.latest_versions.search("body two").ordered_by("title").map(&:id)
    assert_equal [@middle.id, @renamed.id], ids
  end

  test "the workspace page sorts by the current title" do
    sign_in_as(users(:one))

    get workspace_url(@workspace), params: {sort: "title"}

    assert_response :success
    assert_operator response.body.index("Mongoose steady"), :<, response.body.index("Zebra current name")
    assert_not_includes response.body, "Aardvark first name"
  end

  # Links

  test "the links list reports the current title and source and keeps the root's id" do
    link_to_renamed

    get workspace_memory_links_url(@workspace, memories(:one), format: :json), headers: @headers

    assert_response :success
    row = response.parsed_body.find { |link| link["root_id"] == @renamed.id }
    assert_equal @renamed.id, row["id"]
    assert_equal "Zebra current name", row["title"]
    assert_equal "new-source", row["source"]
    assert_equal true, row["current"]
  end

  test "creating a link reports the current title and source" do
    post workspace_memory_links_url(@workspace, memories(:one), format: :json),
      params: {to_memory_id: @renamed.id}.to_json, headers: @headers

    assert_response :created
    assert_equal @renamed.id, response.parsed_body["id"]
    assert_equal "Zebra current name", response.parsed_body["title"]
    assert_equal "new-source", response.parsed_body["source"]
    assert_equal true, response.parsed_body["current"]
  end

  test "the links list doesn't answer 304 after the linked memory's current version is edited in place" do
    link_to_renamed

    get workspace_memory_links_url(@workspace, memories(:one), format: :json), headers: @headers
    etag = response.headers["ETag"]
    last_modified = response.headers["Last-Modified"]

    travel 2.seconds do
      @renamed.current_version.update_with_content({title: "Zebra edited in place"})
      get workspace_memory_links_url(@workspace, memories(:one), format: :json),
        headers: @headers.merge("If-None-Match" => etag, "If-Modified-Since" => last_modified)
    end

    assert_response :success
    assert_includes response.parsed_body.map { |link| link["title"] }, "Zebra edited in place"
  end

  test "related memories on the page show the current title, in that order" do
    link_to_renamed
    MemoryLink.create!(from_memory: memories(:one), to_memory: @middle, created_by: users(:one))
    sign_in_as(users(:one))

    get workspace_memory_url(@workspace, memories(:one))

    assert_response :success
    assert_operator response.body.index("Mongoose steady"), :<, response.body.index("Zebra current name")
    assert_not_includes response.body, "Aardvark first name"
  end

  test "the link picker shows the current title and offers the root" do
    @renamed.rebuild_search_index
    sign_in_as(users(:one))

    get workspace_memory_url(@workspace, memories(:one)), params: {link_q: "Zebra"}

    assert_response :success
    assert_includes response.body, "Zebra current name"
    assert_not_includes response.body, "Aardvark first name"
    assert_select "input[name=to_memory_id][value='#{@renamed.id}']"
  end

  # Other places a root's title shows

  test "palette suggestions show the current title" do
    @renamed.pin!(users(:one))
    sign_in_as(users(:one))

    get search_url, headers: {"Turbo-Frame" => "search_command_results"}

    assert_response :success
    assert_includes response.body, "Zebra current name"
    assert_not_includes response.body, "Aardvark first name"
  end

  test "a list row's delete dialog names the current title" do
    sign_in_as(users(:one))

    get workspace_url(@workspace)

    assert_response :success
    assert_not_includes response.body, "Aardvark first name"
  end

  test "merge candidates compare current titles" do
    twin = Memory.create_with_content(@workspace, title: "Zebra current name", content: "twin")
    @workspace.memories.where.not(id: [@renamed.id, @middle.id, twin.id]).latest_versions.find_each(&:destroy)

    clusters = WorkspaceMergeCandidates.new(@workspace).clusters

    assert(clusters.any? { |cluster| (cluster.memories.map(&:id) & [@renamed.id, twin.id]).size == 2 })
  end

  test "merge candidates don't match on a title the memory no longer has" do
    twin = Memory.create_with_content(@workspace, title: "Aardvark first name", content: "twin")
    @workspace.memories.where.not(id: [@renamed.id, @middle.id, twin.id]).latest_versions.find_each(&:destroy)

    clusters = WorkspaceMergeCandidates.new(@workspace).clusters

    assert_not(clusters.any? { |cluster| (cluster.memories.map(&:id) & [@renamed.id, twin.id]).size == 2 })
  end

  private

  def root_ids
    response.parsed_body.map { |row| row["root_id"] }
  end

  def link_to_renamed
    MemoryLink.create!(from_memory: memories(:one), to_memory: @renamed, created_by: users(:one))
  end
end
