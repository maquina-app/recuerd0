require "test_helper"

class MemoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    sign_in_as(@user)
  end

  test "show renders memory" do
    get workspace_memory_url(@workspace, @memory)
    assert_response :success
  end

  test "new renders blank form without prefill parameters" do
    get new_workspace_memory_url(@workspace)

    assert_response :success
    assert_select "input[name='memory[title]']", 1 do |inputs|
      assert_equal "", inputs.first["value"].to_s
    end
    assert_select "house-md[name='memory[content]']", 1 do |editors|
      assert_equal "", editors.first.text
    end
    assert_select ".tag-badge", count: 0
    assert_select "input[type='hidden'][name='memory[tags][]']", count: 0
    assert_select "input[type='radio'][name='memory[category]'][value='general'][checked]", count: 1
  end

  test "new prefills title content category and tags without persisting records" do
    assert_no_difference "Memory.count" do
      assert_no_difference "Content.count" do
        get new_workspace_memory_url(@workspace), params: {
          title: "Everybody Lies",
          content: "It's never lupus.",
          category: "decision",
          tags: ["diagnostics"]
        }
      end
    end

    assert_response :success
    assert_select "input[name='memory[title]'][value='Everybody Lies']", count: 1
    assert_select "house-md[name='memory[content]']", text: "It's never lupus.", count: 1
    assert_select "input[type='radio'][name='memory[category]'][value='decision'][checked]", count: 1
    assert_select ".tag-badge .tag-label", text: "diagnostics", count: 1
    assert_select "input[type='hidden'][name='memory[tags][]'][value='diagnostics']", count: 1
  end

  test "new drops invalid category and keeps general selected" do
    get new_workspace_memory_url(@workspace), params: {category: "bogus"}

    assert_response :success
    assert_select "input[type='radio'][name='memory[category]'][value='bogus']", count: 0
    assert_select "input[type='radio'][name='memory[category]'][value='general'][checked]", count: 1
  end

  test "new keeps only non-blank string tags without normalizing them" do
    get new_workspace_memory_url(@workspace), params: {
      tags: ["diagnostics", "", " ", " differential ", "diagnostics"]
    }

    assert_response :success
    assert_select ".tag-badge", count: 3
    hidden_tags = css_select("input[type='hidden'][name='memory[tags][]']").map { |input| input["value"] }
    assert_equal ["diagnostics", " differential ", "diagnostics"], hidden_tags
  end

  test "new ignores nested and unknown prefill parameters" do
    get new_workspace_memory_url(@workspace), params: {
      memory: {
        title: "Nested title",
        content: "Nested content",
        category: "decision",
        tags: ["nested"]
      },
      source: "Unknown source"
    }

    assert_response :success
    assert_select "input[name='memory[title]']", 1 do |inputs|
      assert_equal "", inputs.first["value"].to_s
    end
    assert_select "house-md[name='memory[content]']", 1 do |editors|
      assert_equal "", editors.first.text
    end
    assert_select ".tag-badge", count: 0
    assert_select "input[name='memory[source]']", 1 do |inputs|
      assert_equal "", inputs.first["value"].to_s
    end
    assert_select "input[type='radio'][name='memory[category]'][value='general'][checked]", count: 1
  end

  test "create saves memory with content" do
    assert_difference("Memory.count") do
      post workspace_memories_url(@workspace), params: {
        memory: {title: "New Memory", content: "Some content", tags: ["test"]}
      }
    end
  end

  test "edit renders form" do
    get edit_workspace_memory_url(@workspace, @memory)
    assert_response :success
  end

  test "update changes memory" do
    patch workspace_memory_url(@workspace, @memory), params: {
      memory: {title: "Updated Title", content: "Updated body"}
    }
    assert_redirected_to workspace_memory_url(@workspace, @memory)
    assert_equal "Updated Title", @memory.reload.title
  end

  test "show renders root memory without resolving to latest version" do
    parent = memories(:versioned_parent)
    parent.create_version!(title: "Latest Version", content: "Latest content")

    get workspace_memory_url(parent.workspace, parent)
    assert_response :success
    assert_match parent.display_title, response.body
  end

  test "show renders specific version when navigating to child version" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(title: "V2 Specific", content: "V2 content")
    parent.create_version!(title: "V3 Latest", content: "V3 content")

    get workspace_memory_url(parent.workspace, v2)
    assert_response :success
    assert_match "V2 Specific", response.body
  end

  test "show sets viewing_old_version flag for non-current versions" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(title: "V2", content: "V2 content")
    parent.create_version!(title: "V3 Latest", content: "V3 content")

    get workspace_memory_url(parent.workspace, v2)
    assert_response :success
    assert_match I18n.t("memories.show.old_version_title", version: v2.version_label), response.body
  end

  test "show does not show old version alert for current version" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(title: "V2 Latest", content: "V2 content")

    get workspace_memory_url(parent.workspace, v2)
    assert_response :success
    assert_no_match(/#{Regexp.escape(I18n.t("memories.show.old_version_title", version: v2.version_label))}/, response.body)
  end

  test "show hides edit actions for old versions" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(title: "V2", content: "V2 content")
    parent.create_version!(title: "V3 Latest", content: "V3 content")

    get workspace_memory_url(parent.workspace, v2)
    assert_response :success
    assert_no_match edit_workspace_memory_path(parent.workspace, v2), response.body
  end

  test "workspace show filters memories by category" do
    Memory.create_with_content(@workspace, title: "OnlyDecision", content: "b", category: "decision")
    Memory.create_with_content(@workspace, title: "OnlyDiscovery", content: "b", category: "discovery")

    get workspace_url(@workspace, category: "decision")
    assert_response :success
    assert_match "OnlyDecision", response.body
    assert_no_match(/OnlyDiscovery/, response.body)
  end

  test "destroy removes memory" do
    assert_difference("Memory.count", -1) do
      delete workspace_memory_url(@workspace, @memory)
    end
  end
end
