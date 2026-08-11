require "test_helper"
require "rake"

class SearchTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("search:embed_backfill")
    @task = Rake::Task["search:embed_backfill"]
  end

  test "backfill scopes workspaces and reports exact embedded and unchanged counts" do
    first_workspace = workspace_without_starter("Backfill first")
    second_workspace = workspace_without_starter("Backfill second")
    2.times do |index|
      Memory.create_with_content(first_workspace, title: "First #{index}", content: "Body")
    end
    Memory.create_with_content(second_workspace, title: "Second", content: "Body")
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(provider: provider) do
      output = invoke_task(first_workspace.id.to_s)
      assert_includes output, "2 embedded, 0 unchanged"
      assert_equal first_workspace.memories.latest_versions.pluck(:id).sort,
        MemoryEmbedding.order(:memory_id).pluck(:memory_id)

      provider.embedded_texts.clear
      output = invoke_task(first_workspace.id.to_s)
      assert_includes output, "0 embedded, 2 unchanged"
      assert_empty provider.embedded_texts

      output = invoke_task(second_workspace.id.to_s)
      assert_includes output, "1 embedded, 0 unchanged"
      assert_equal 3, MemoryEmbedding.count

      MemoryEmbedding.delete_all
      total_roots = Memory.latest_versions.count
      provider.embedded_texts.clear
      output = invoke_task
      assert_includes output, "#{total_roots} embedded, 0 unchanged"

      provider.embedded_texts.clear
      output = invoke_task
      assert_includes output, "0 embedded, #{total_roots} unchanged"
      assert_empty provider.embedded_texts
    end
  end

  test "flag-off backfill aborts before embedding table access" do
    embedding_sql = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      embedding_sql << payload[:sql] if payload[:sql].match?(/memory_embeddings/i)
    end

    with_hybrid_retrieval(false) do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        error = assert_raises(SystemExit) { invoke_task }
        assert_equal 1, error.status
      end
    end

    assert_empty embedding_sql
  end

  private

  def invoke_task(workspace_id = nil)
    @task.reenable
    capture_io { @task.invoke(workspace_id) }.first
  end

  def workspace_without_starter(name)
    accounts(:one).workspaces.create!(name: name).tap do |workspace|
      workspace.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    end
  end
end
