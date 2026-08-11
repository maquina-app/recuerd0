require "test_helper"

class MemoryRetrievalTest < ActiveSupport::TestCase
  setup do
    @workspace = workspace_without_starter("Retrieval workspace")
  end

  test "semantic retrieval isolates the root relation and current model" do
    provider = FakeEmbeddingProvider.new(vectors: {"restore hangs" => [1.0, 0.0, 0.0]})
    match = Memory.create_with_content(@workspace, title: "Checkpoint", content: "Storage mount")
    weaker = Memory.create_with_content(@workspace, title: "Other", content: "Unrelated")
    stale = Memory.create_with_content(@workspace, title: "Stale model", content: "Storage mount")
    foreign_workspace = workspace_without_starter("Other retrieval workspace")
    foreign = Memory.create_with_content(foreign_workspace, title: "Foreign", content: "Storage mount")
    create_memory_embedding(match, vector: [1.0, 0.0, 0.0], model: provider.model)
    create_memory_embedding(weaker, vector: [0.0, 1.0, 0.0], model: provider.model)
    create_memory_embedding(stale, vector: [1.0, 0.0, 0.0], model: "previous-model")
    create_memory_embedding(foreign, vector: [1.0, 0.0, 0.0], model: provider.model)

    ids = MemoryRetrieval.new(
      relation: @workspace.memories.latest_versions,
      provider: provider
    ).ranked_ids(query: "restore hangs", mode: "semantic")

    assert_equal [match.id, weaker.id], ids
    assert_equal ["restore hangs"], provider.embedded_texts
    assert_not_includes ids, stale.id
    assert_not_includes ids, foreign.id
  end

  test "semantic and hybrid bridge a vocabulary gap that lexical search misses" do
    query = "restore hangs"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})
    checkpoint = Memory.create_with_content(
      @workspace,
      title: "Checkpoint stalls on the storage mount",
      content: "The snapshot process waits indefinitely."
    )
    unrelated = Memory.create_with_content(
      @workspace,
      title: "Lunch notes",
      content: "Order soup."
    )
    create_memory_embedding(checkpoint, vector: [1.0, 0.0, 0.0], model: provider.model)
    create_memory_embedding(unrelated, vector: [0.0, 1.0, 0.0], model: provider.model)
    relation = @workspace.memories.latest_versions

    assert_empty relation.search(query)
    assert_equal checkpoint.id,
      MemoryRetrieval.new(relation: relation, provider: provider)
        .ranked_ids(query: query, mode: "semantic").first
    assert_equal checkpoint.id,
      MemoryRetrieval.new(relation: relation, provider: provider)
        .ranked_ids(query: query, mode: "hybrid").first
  end

  test "reciprocal rank fusion matches the hand-computed order" do
    a, b, c, d = 1, 2, 3, 4
    scores = MemoryRetrieval.rrf_scores([a, b, c], [c, b, d])
    order = scores.sort_by { |id, score| [-score, id] }.map(&:first)

    assert_equal [c, b, a, d], order
    assert_in_delta 1.0 / 61, scores[a]
    assert_in_delta 2.0 / 62, scores[b]
    assert_in_delta(1.0 / 63 + 1.0 / 61, scores[c])
    assert_in_delta 1.0 / 63, scores[d]
  end

  test "semantic ties use updated time then descending id" do
    provider = FakeEmbeddingProvider.new(vectors: {"same score" => [1.0, 0.0, 0.0]})
    older = Memory.create_with_content(@workspace, title: "Older", content: "Body")
    lower_id = Memory.create_with_content(@workspace, title: "Lower id", content: "Body")
    higher_id = Memory.create_with_content(@workspace, title: "Higher id", content: "Body")
    tied_at = 1.day.ago
    older.update_column(:updated_at, 2.days.ago)
    lower_id.update_column(:updated_at, tied_at)
    higher_id.update_column(:updated_at, tied_at)
    [older, lower_id, higher_id].each do |memory|
      create_memory_embedding(memory, vector: [1.0, 0.0, 0.0], model: provider.model)
    end

    ids = MemoryRetrieval.new(
      relation: @workspace.memories.latest_versions,
      provider: provider
    ).ranked_ids(query: "same score", mode: "semantic")

    assert_equal [higher_id.id, lower_id.id, older.id], ids
  end

  test "decay has a thirty-day half-life floor and category exemption" do
    now = Time.zone.parse("2026-08-11 12:00:00")

    assert_in_delta 1.0, decay_factor("general", now + 1.day, now)
    assert_in_delta 0.5, decay_factor("general", now - 30.days, now)
    assert_in_delta 0.25, decay_factor("general", now - 60.days, now)
    assert_in_delta 0.25, decay_factor("general", now - 365.days, now)
    %w[decision preference discovery].each do |category|
      assert_in_delta 1.0, decay_factor(category, now - 365.days, now)
    end
  end

  test "hybrid decay re-sorts fused scores with stable metadata tie breakers" do
    general = Memory.create_with_content(
      @workspace,
      title: "Old general",
      content: "Body",
      category: "general"
    )
    decision = Memory.create_with_content(
      @workspace,
      title: "Old decision",
      content: "Body",
      category: "decision"
    )
    now = Time.zone.parse("2026-08-11 12:00:00")
    general.update_column(:updated_at, now - 30.days)
    decision.update_column(:updated_at, now - 365.days)
    retrieval = MemoryRetrieval.new(
      relation: @workspace.memories.latest_versions,
      provider: FakeEmbeddingProvider.new,
      now: now
    )

    decayed = retrieval.send(:apply_decay, {general.id => 1.0, decision.id => 0.6})
    ids = retrieval.send(:sort_scores, decayed)

    assert_in_delta 0.5, decayed[general.id]
    assert_in_delta 0.6, decayed[decision.id]
    assert_equal [decision.id, general.id], ids
  end

  private

  def workspace_without_starter(name)
    accounts(:one).workspaces.create!(name: name).tap do |workspace|
      workspace.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    end
  end

  def decay_factor(category, updated_at, now)
    MemoryRetrieval.decay_factor(category: category, updated_at: updated_at, now: now)
  end
end
