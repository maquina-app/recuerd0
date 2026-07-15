require "test_helper"

class WorkspaceMergeCandidatesTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
    @workspace.memories.destroy_all # start from a clean slate for deterministic clusters
  end

  test "clusters memories with identical titles and shared tags" do
    Memory.create_with_content(@workspace, title: "Deploy runbook", content: "b", tags: ["ops"])
    Memory.create_with_content(@workspace, title: "Deploy runbook", content: "b", tags: ["ops"])

    clusters = WorkspaceMergeCandidates.new(@workspace).clusters

    assert_equal 1, clusters.size
    assert_equal 2, clusters.first.memories.size
    assert_operator clusters.first.score, :>=, 0.5
    assert_includes clusters.first.reasons, "similar title"
    assert_includes clusters.first.reasons, "shared tags"
  end

  test "does not cluster unrelated memories" do
    Memory.create_with_content(@workspace, title: "Quarterly finance report", content: "b", tags: ["finance"])
    Memory.create_with_content(@workspace, title: "Cafeteria menu", content: "b", tags: ["food"])

    assert_empty WorkspaceMergeCandidates.new(@workspace).clusters
  end

  test "transitively similar memories collapse into one cluster" do
    3.times { Memory.create_with_content(@workspace, title: "Onboarding checklist", content: "b", tags: ["hr"]) }

    clusters = WorkspaceMergeCandidates.new(@workspace).clusters

    assert_equal 1, clusters.size
    assert_equal 3, clusters.first.memories.size
  end

  test "min_score raises the bar" do
    Memory.create_with_content(@workspace, title: "Release notes v1", content: "b", tags: ["release"])
    Memory.create_with_content(@workspace, title: "Release notes v2", content: "b", tags: ["release"])

    assert_empty WorkspaceMergeCandidates.new(@workspace, min_score: 0.99).clusters
  end

  test "returns nothing for fewer than two memories" do
    Memory.create_with_content(@workspace, title: "Lonely", content: "b")
    assert_empty WorkspaceMergeCandidates.new(@workspace).clusters
  end
end
