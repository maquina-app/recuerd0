require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "requires name" do
    workspace = Workspace.new(name: "", user: users(:one))
    assert_not workspace.valid?
    assert workspace.errors[:name].any?
  end

  test "enforces name max length" do
    workspace = Workspace.new(name: "a" * 101, user: users(:one))
    assert_not workspace.valid?
    assert workspace.errors[:name].any?
  end

  test "status returns :active for normal workspace" do
    assert_equal :active, workspaces(:one).status
  end

  test "status returns :archived" do
    assert_equal :archived, workspaces(:archived).status
  end

  test "status returns :deleted" do
    assert_equal :deleted, workspaces(:deleted).status
  end

  test "soft_delete sets deleted_at" do
    workspace = workspaces(:one)
    workspace.soft_delete
    assert workspace.deleted_at.present?
  end

  test "restore clears deleted_at" do
    workspace = workspaces(:deleted)
    workspace.restore
    assert_nil workspace.deleted_at
  end

  test "search finds by name" do
    results = Workspace.search("Project")
    assert_includes results, workspaces(:one)
  end
end
