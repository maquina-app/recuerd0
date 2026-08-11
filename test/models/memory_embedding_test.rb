require "test_helper"
require "minitest/mock"

class MemoryEmbeddingTest < ActiveSupport::TestCase
  test "float32 vectors round-trip portably and reject invalid values" do
    values = [1.25, -2.5, 0.125]
    packed = MemoryEmbedding.pack_vector(values, dimensions: 3)

    assert_equal 12, packed.bytesize
    unpacked = MemoryEmbedding.unpack_vector(packed, dimensions: 3)
    values.zip(unpacked).each { |expected, actual| assert_in_delta expected, actual, 0.000001 }

    assert_raises(MemoryEmbedding::InvalidVector) do
      MemoryEmbedding.pack_vector([1.0, 2.0], dimensions: 3)
    end
    assert_raises(MemoryEmbedding::InvalidVector) do
      MemoryEmbedding.pack_vector([1.0, Float::NAN, 3.0], dimensions: 3)
    end
    assert_raises(MemoryEmbedding::InvalidVector) do
      MemoryEmbedding.pack_vector([1.0, Float::INFINITY, 3.0], dimensions: 3)
    end
    assert_raises(MemoryEmbedding::InvalidVector) do
      MemoryEmbedding.pack_vector([1.0, Object.new, 3.0], dimensions: 3)
    end
  end

  test "callbacks embed the newest version text under the root id" do
    provider = FakeEmbeddingProvider.new
    root = nil
    current = nil

    with_hybrid_retrieval(provider: provider) do
      root = Memory.create_with_content(
        workspaces(:one),
        title: "Original title",
        content: "Original body"
      )
      current = root.create_version!(title: "Current title", content: "Current body")
    end

    embedding = MemoryEmbedding.find_by!(memory_id: root.id)
    expected_text = "Current title\n\nCurrent body"
    assert_equal root.id, embedding.memory_id
    assert_not_equal current.id, embedding.memory_id
    assert_equal provider.model, embedding.model
    assert_equal Digest::SHA256.hexdigest(expected_text), embedding.content_hash
    assert_equal expected_text, provider.embedded_texts.last
  end

  test "title and body updates refresh the exact embedded text" do
    memory = Memory.create_with_content(
      workspaces(:one),
      title: "Before",
      content: "Old body"
    )
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(provider: provider) do
      memory.update!(title: "After")
      assert_equal "After\n\nOld body", provider.embedded_texts.last

      memory.content.update!(body: "New body")
      assert_equal "After\n\nNew body", provider.embedded_texts.last
    end

    assert_equal Digest::SHA256.hexdigest("After\n\nNew body"),
      MemoryEmbedding.find_by!(memory_id: memory.id).content_hash
  end

  test "matching content hash and model skip before loading the provider" do
    memory = Memory.create_with_content(workspaces(:one), title: "Stable", content: "Same")
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(provider: provider) do
      assert_equal :embedded, memory.rebuild_embedding
      provider.embedded_texts.clear
      assert_equal :unchanged, memory.rebuild_embedding
    end

    assert_empty provider.embedded_texts
  end

  test "a model change re-embeds unchanged content" do
    memory = Memory.create_with_content(workspaces(:one), title: "Stable", content: "Same")
    old_provider = FakeEmbeddingProvider.new(model: "old-model")
    new_provider = FakeEmbeddingProvider.new(model: "new-model")

    with_hybrid_retrieval(provider: old_provider) { memory.rebuild_embedding }
    with_hybrid_retrieval(provider: new_provider) do
      assert_equal :embedded, memory.rebuild_embedding
    end

    assert_equal ["Stable\n\nSame"], new_provider.embedded_texts
    assert_equal "new-model", MemoryEmbedding.find_by!(memory_id: memory.id).model
  end

  test "flag-off writes never invoke the provider" do
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(false, provider: provider) do
      assert_no_difference -> { MemoryEmbedding.count } do
        memory = Memory.create_with_content(workspaces(:one), title: "Disabled", content: "Body")
        memory.update!(title: "Still disabled")
        memory.content.update!(body: "Still no embedding")
      end
    end

    assert_empty provider.embedded_texts
  end

  test "callback failures clean stale rows without surfacing from committed writes" do
    memory = Memory.create_with_content(workspaces(:one), title: "Before", content: "Secret body")
    good_provider = FakeEmbeddingProvider.new(model: "working-model")
    with_hybrid_retrieval(provider: good_provider) { memory.rebuild_embedding }
    assert MemoryEmbedding.exists?(memory_id: memory.id)

    failing_provider = FakeEmbeddingProvider.new(model: "broken-model") do
      raise EmbeddingProviders::Error, "provider unavailable"
    end
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)

    Rails.stub(:logger, logger) do
      with_hybrid_retrieval(provider: failing_provider) do
        assert_nothing_raised { memory.update!(title: "Committed title") }
      end
    end

    assert_equal "Committed title", memory.reload.title
    assert_not MemoryEmbedding.exists?(memory_id: memory.id)
    assert_includes output.string, "root_id=#{memory.id}"
    assert_includes output.string, "broken-model"
    assert_includes output.string, "EmbeddingProviders::Error"
    assert_not_includes output.string, "Secret body"
  end

  test "explicit maintenance raises provider failures" do
    memory = Memory.create_with_content(workspaces(:one), title: "Explicit", content: "Body")
    provider = FakeEmbeddingProvider.new { raise EmbeddingProviders::Error, "failed" }

    with_hybrid_retrieval(provider: provider) do
      assert_raises(EmbeddingProviders::Error) { memory.rebuild_embedding }
    end
  end

  test "database cascade deletes a root embedding while the flag is off" do
    memory = Memory.create_with_content(workspaces(:one), title: "Delete", content: "Body")
    create_memory_embedding(memory, vector: [1.0, 0.0, 0.0])

    with_hybrid_retrieval(false) { memory.destroy! }

    assert_not MemoryEmbedding.exists?(memory_id: memory.id)
  end
end

class EmbeddingProvidersTest < ActiveSupport::TestCase
  test "tests use the injected provider without constructing Informers" do
    fake = EmbeddingProviders.provider_override

    Informers.stub(:pipeline, ->(*) { flunk "Informers pipeline must not be constructed in tests" }) do
      assert_same fake, EmbeddingProviders.application
      assert_same fake, EmbeddingProviders.backfill
      assert_equal 3, EmbeddingProviders.application.embed("deterministic").length
    end
  end

  test "factory keeps application providers offline and reserves remote loading for backfill" do
    previous_override = EmbeddingProviders.provider_override
    EmbeddingProviders.provider_override = nil

    Informers.stub(:pipeline, ->(*) { flunk "building a provider must not construct a pipeline" }) do
      application = EmbeddingProviders.application
      backfill = EmbeddingProviders.backfill

      assert_equal true, application.instance_variable_get(:@local_files_only)
      assert_equal false, backfill.instance_variable_get(:@local_files_only)
      assert_equal "sentence-transformers/all-MiniLM-L6-v2", application.model
      assert_equal 384, application.dimensions
    end
  ensure
    EmbeddingProviders.provider_override = previous_override
  end

  test "unknown configured providers raise a configuration error" do
    previous_name = Rails.configuration.x.hybrid_retrieval_provider
    previous_override = EmbeddingProviders.provider_override
    Rails.configuration.x.hybrid_retrieval_provider = "unknown"
    EmbeddingProviders.provider_override = nil

    error = assert_raises(EmbeddingProviders::ConfigurationError) do
      EmbeddingProviders.application
    end
    assert_includes error.message, "unknown"
  ensure
    Rails.configuration.x.hybrid_retrieval_provider = previous_name
    EmbeddingProviders.provider_override = previous_override
  end

  test "test environment leaves the Informers cache directory unset" do
    assert_nil Rails.configuration.x.hybrid_retrieval_cache_dir
  end
end
