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

    ids = retrieval(provider).ranked_ids(query: "restore hangs")

    assert_equal [match.id, weaker.id], ids
    assert_equal ["restore hangs"], provider.embedded_texts
    assert_not_includes ids, stale.id
    assert_not_includes ids, foreign.id
  end

  test "semantic retrieval bridges a vocabulary gap that lexical search misses" do
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

    assert_empty @workspace.memories.latest_versions.search(query)
    assert_equal checkpoint.id, retrieval(provider).ranked_ids(query: query).first
  end

  test "mixed-case superseded tags demote a higher raw similarity" do
    query = "restore hangs"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})
    superseded = Memory.create_with_content(
      @workspace,
      title: "Superseded",
      content: "Body",
      tags: ["archive", "SuPeRsEdEd"]
    )
    current = Memory.create_with_content(@workspace, title: "Current", content: "Body")
    create_memory_embedding(superseded, vector: [1.0, 0.0, 0.0], model: provider.model)
    create_memory_embedding(current, vector: [0.6, 0.8, 0.0], model: provider.model)

    assert_equal [current.id, superseded.id], retrieval(provider).ranked_ids(query: query)
  end

  test "nil empty malformed and non-array tags do not crash or demote" do
    query = "same score"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})
    memories = [nil, "[]", "{malformed", '"superseded"'].map.with_index do |tags, index|
      memory = Memory.create_with_content(
        @workspace,
        title: "Metadata #{index}",
        content: "Body"
      )
      Memory.where(id: memory.id).update_all(["tags = ?", tags])
      create_memory_embedding(memory, vector: [1.0, 0.0, 0.0], model: provider.model)
      memory
    end
    tied_at = 1.day.ago
    Memory.where(id: memories.map(&:id)).update_all(updated_at: tied_at)

    ids = retrieval(provider).ranked_ids(query: query)

    assert_equal memories.map(&:id).sort.reverse, ids
    refute retrieval(provider).send(:obsolete?, [])
  end

  test "every obsolete tag demotes the way superseded does" do
    query = "same score"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})
    retrieval = retrieval(provider)

    Memory::OBSOLETE_TAGS.each do |tag|
      assert retrieval.send(:obsolete?, [tag]), "#{tag} should be obsolete"
      assert retrieval.send(:obsolete?, [tag.upcase]), "#{tag.upcase} should be obsolete"
    end
    refute retrieval.send(:obsolete?, ["deprecated-api"])

    obsolete = Memory.create_with_content(@workspace, title: "Retired", content: "Body", tags: ["Obsolete"])
    deprecated = Memory.create_with_content(@workspace, title: "Old", content: "Body", tags: ["deprecated"])
    current = Memory.create_with_content(@workspace, title: "Current", content: "Body")
    [obsolete, deprecated].each { |m| create_memory_embedding(m, vector: [1.0, 0.0, 0.0], model: provider.model) }
    create_memory_embedding(current, vector: [0.6, 0.8, 0.0], model: provider.model)

    ranked = retrieval.ranked_ids(query: query)

    assert_equal current.id, ranked.first
    assert_equal [deprecated.id, obsolete.id].sort, ranked.drop(1).sort
  end

  test "superseded demotion happens before the semantic top fifty cutoff" do
    query = "restore hangs"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})

    49.times do |index|
      memory = Memory.create_with_content(
        @workspace,
        title: "Strong current #{index}",
        content: "Body"
      )
      create_memory_embedding(memory, vector: [0.8, 0.6, 0.0], model: provider.model)
    end
    superseded = Memory.create_with_content(
      @workspace,
      title: "Raw strongest but superseded",
      content: "Body",
      tags: ["superseded"]
    )
    current = Memory.create_with_content(@workspace, title: "Current at cutoff", content: "Body")
    create_memory_embedding(superseded, vector: [1.0, 0.0, 0.0], model: provider.model)
    create_memory_embedding(current, vector: [0.6, 0.8, 0.0], model: provider.model)

    ids = retrieval(provider).ranked_ids(query: query)

    assert_equal MemoryRetrieval::SEMANTIC_TOP_K, ids.size
    assert_includes ids, current.id
    assert_not_includes ids, superseded.id
  end

  test "a superseded memory remains eligible without a stronger competitor" do
    query = "restore hangs"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})
    superseded = Memory.create_with_content(
      @workspace,
      title: "Only candidate",
      content: "Body",
      tags: ["superseded"]
    )
    create_memory_embedding(superseded, vector: [1.0, 0.0, 0.0], model: provider.model)

    assert_equal [superseded.id], retrieval(provider).ranked_ids(query: query)
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

    ids = retrieval(provider).ranked_ids(query: "same score")

    assert_equal [higher_id.id, lower_id.id, older.id], ids
  end

  test "related keeps matches above the floor, most similar first, minus keyword hits" do
    provider = FakeEmbeddingProvider.new(vectors: {"restore hangs" => [1.0, 0.0, 0.0]})
    closest = Memory.create_with_content(@workspace, title: "Checkpoint stalls", content: "Mount")
    close = Memory.create_with_content(@workspace, title: "Snapshot waits", content: "Disk")
    keyword_hit = Memory.create_with_content(@workspace, title: "Restore hangs", content: "Body")
    unrelated = Memory.create_with_content(@workspace, title: "Lunch", content: "Soup")
    create_memory_embedding(closest, vector: [1.0, 0.1, 0.0], model: provider.model)
    create_memory_embedding(close, vector: [0.6, 0.8, 0.0], model: provider.model)
    create_memory_embedding(keyword_hit, vector: [1.0, 0.0, 0.0], model: provider.model)
    create_memory_embedding(unrelated, vector: [0.2, 1.0, 0.0], model: provider.model)

    related = retrieval(provider).related(query: "restore hangs", excluding: [keyword_hit.id])

    assert_equal [closest.id, close.id], related.map(&:first)
    assert_in_delta 0.6, related.last.last, 0.001
  end

  test "related returns at most the related limit" do
    provider = FakeEmbeddingProvider.new(vectors: {"restore hangs" => [1.0, 0.0, 0.0]})
    (MemoryRetrieval::RELATED_LIMIT + 2).times do |index|
      memory = Memory.create_with_content(@workspace, title: "Close #{index}", content: "Body")
      create_memory_embedding(memory, vector: [1.0, 0.0, 0.0], model: provider.model)
    end

    assert_equal MemoryRetrieval::RELATED_LIMIT,
      retrieval(provider).related(query: "restore hangs").size
  end

  test "related_to runs only when keyword search found fewer than three hits" do
    provider = FakeEmbeddingProvider.new(vectors: {"restore hangs" => [1.0, 0.0, 0.0]})
    memory = Memory.create_with_content(@workspace, title: "Checkpoint stalls", content: "Mount")
    create_memory_embedding(memory, vector: [1.0, 0.0, 0.0], model: provider.model)
    roots = @workspace.memories.latest_versions

    with_hybrid_retrieval(provider: provider) do
      assert_empty roots.related_to("restore hangs", keyword_count: MemoryRetrieval::RELATED_WHEN_FEWER_THAN)
      assert_empty provider.embedded_texts

      matches = roots.related_to("restore hangs", keyword_count: 0)
      assert_equal [memory], matches.map(&:memory)
      assert_in_delta 1.0, matches.first.similarity
    end
  end

  test "related_to does nothing with the flag off" do
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(false, provider: provider) do
      assert_empty @workspace.memories.latest_versions.related_to("restore hangs", keyword_count: 0)
    end
    assert_empty provider.embedded_texts
  end

  test "related_to embeds the query words without FTS syntax" do
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(provider: provider) do
      @workspace.memories.latest_versions.related_to(%("restore hangs" OR title:checkpoint*), keyword_count: 0)
    end

    assert_equal ["restore hangs checkpoint"], provider.embedded_texts
  end

  test "related_to leaves keyword search standing when the model fails" do
    provider = FakeEmbeddingProvider.new { raise EmbeddingProviders::Error, "model unavailable" }

    with_hybrid_retrieval(provider: provider) do
      assert_equal [], @workspace.memories.latest_versions.related_to("restore hangs", keyword_count: 0)
    end
  end

  private

  def retrieval(provider)
    MemoryRetrieval.new(relation: @workspace.memories.latest_versions, provider: provider)
  end

  def workspace_without_starter(name)
    accounts(:one).workspaces.create!(name: name).tap do |workspace|
      workspace.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    end
  end
end
