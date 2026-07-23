module Mcp
  # Read/write operations exposed to MCP clients. Each method takes the
  # authenticated account and the tool arguments, and returns a plain Hash/Array.
  # All queries are scoped to the account for tenant isolation.
  module Tools
    module_function

    def list_workspaces(account, _args = {})
      account.workspaces.active.ordered.map do |workspace|
        {
          id: workspace.id.to_s,
          name: workspace.name,
          description: workspace.description,
          memories_count: workspace.memories_count,
          created_at: workspace.created_at.iso8601,
          updated_at: workspace.updated_at.iso8601
        }
      end
    end

    # Default/max page sizes for list_memories. A workspace can hold hundreds of
    # memories; without a cap a single tool call returns an unbounded blob and the
    # client can't tell it was truncated. The envelope (total_count/has_more)
    # gives callers an explicit signal to page.
    LIST_DEFAULT_LIMIT = 50
    LIST_MAX_LIMIT = 200

    # Cap on ids accepted by read_memories in one call, to bound response size.
    BATCH_READ_LIMIT = 50

    def list_memories(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])
      validate_category!(args["category"])
      limit = clamp_limit(args["limit"])
      offset = [args["offset"].to_i, 0].max
      query = Memory.normalize_search_query(args["query"])

      memories = workspace.memories.latest_versions
      memories = memories.search(query) if query.present?
      memories = memories.by_category(args["category"]) if args["category"].present?
      sort = Memory.resolve_sort(args["sort"], query: query)
      memories = memories.ordered_by(sort)

      total_count = memories.count
      page = memories.offset(offset).limit(limit)

      {
        memories: page.map { |memory| memory_json(memory.resolve_current_version) },
        total_count: total_count,
        has_more: offset + limit < total_count,
        next_offset: (offset + limit < total_count) ? offset + limit : nil
      }
    end

    def read_memory(account, args = {})
      memory = find_memory(account, args["memory_id"]).resolve_current_version

      memory_json(memory).merge(content: memory.content&.body&.content.to_s)
    end

    # Batch counterpart to read_memory: fetch several memories (with content) in a
    # single call. Unknown/foreign ids are reported in `missing` rather than failing
    # the whole call, so a caller verifying a set of candidates gets partial results.
    def read_memories(account, args = {})
      ids = Array(args["memory_ids"]).map(&:to_s).reject(&:blank?).first(BATCH_READ_LIMIT)

      found = Memory.joins(:workspace)
        .where(workspaces: {account_id: account.id})
        .latest_versions
        .where(id: ids)
        .index_by { |memory| memory.id.to_s }

      memories = ids.filter_map do |id|
        memory = found[id]&.resolve_current_version
        next unless memory

        memory_json(memory).merge(content: memory.content&.body&.content.to_s)
      end

      {memories: memories, missing: ids - found.keys}
    end

    def create_memory(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])
      validate_category!(args["category"])
      category = args["category"].presence || Memory::DEFAULT_CATEGORY

      memory = Memory.create_with_content(
        workspace,
        title: args["title"],
        category: category,
        content: args["content"],
        tags: normalize_tags(args["tags"]),
        source: args["source"] # server-injected by McpController, never client-supplied
      )
      raise ToolError, memory.errors.full_messages.to_sentence if memory.errors.any?

      memory_json(memory)
    end

    def update_memory(account, args = {})
      memory = find_memory(account, args["memory_id"])

      attributes = {}
      attributes[:title] = args["title"] if args["title"].present?
      attributes[:content] = args["content"] if args.key?("content")
      attributes[:tags] = normalize_tags(args["tags"]) if args.key?("tags")
      if args["category"].present?
        validate_category!(args["category"])
        attributes[:category] = args["category"]
      end

      memory.update_with_content(attributes)
      raise ToolError, memory.errors.full_messages.to_sentence if memory.errors.any?

      memory_json(memory.reload)
    end

    # Appends a new immutable version to an existing memory (vs. update_memory,
    # which overwrites in place). Omitted fields inherit from the latest version.
    def create_version(account, args = {})
      memory = find_memory(account, args["memory_id"])
      validate_category!(args["category"])
      category = args["category"].presence

      version = memory.create_version!(
        title: args["title"],
        category: category,
        content: args["content"],
        tags: (normalize_tags(args["tags"]) if args.key?("tags")),
        source: args["source"] # server-injected — provenance of this version
      )
      raise ToolError, version.errors.full_messages.to_sentence if version.errors.any?

      memory_json(version)
    end

    # Cross-workspace "see also" links between memories in the same account.
    # Links are undirected and unlabeled — MemoryLink#normalize_order canonicalizes
    # the pair, so link_memories(a, b) and link_memories(b, a) are the same link.
    def list_memory_links(account, args = {})
      memory = find_memory(account, args["memory_id"])

      memory.linked_memories.latest_versions.map do |linked|
        memory_json(linked.resolve_current_version)
      end
    end

    def link_memories(account, args = {})
      memory = find_memory(account, args["memory_id"])
      other = find_memory(account, args["to_memory_id"])
      raise ToolError, "Cannot link a memory to itself" if memory.id == other.id

      link = MemoryLink.new(from_memory: memory, to_memory: other)
      raise ToolError, link.errors.full_messages.to_sentence unless link.save

      {linked: true, memory_id: memory.id.to_s, to_memory_id: other.id.to_s}
    end

    def unlink_memories(account, args = {})
      memory = find_memory(account, args["memory_id"])
      other = find_memory(account, args["to_memory_id"])

      link = MemoryLink.where(
        "(from_memory_id = ? AND to_memory_id = ?) OR (from_memory_id = ? AND to_memory_id = ?)",
        memory.id, other.id, other.id, memory.id
      ).first
      raise ToolError, "Link not found" unless link

      link.destroy
      {unlinked: true, memory_id: memory.id.to_s, to_memory_id: other.id.to_s}
    end

    # Aggregate rollup for a workspace, computed server-side so callers can get
    # counts and trends without paging the full memory list (which is what hit the
    # truncation ceiling that motivated the envelope on list_memories).
    def workspace_stats(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])
      roots = workspace.memories.latest_versions

      counts_by_category = Memory::CATEGORIES.index_with { 0 }.merge(roots.group(:category).count)
      workspace_memory_ids = workspace.memories.select(:id)

      {
        workspace_id: workspace.id.to_s,
        total_memories: roots.count,
        total_versions: workspace.memories.count,
        counts_by_category: counts_by_category,
        total_links: MemoryLink
          .where(from_memory_id: workspace_memory_ids)
          .or(MemoryLink.where(to_memory_id: workspace_memory_ids))
          .count,
        top_tags: top_tags(roots),
        memories_by_week: roots.group(Arel.sql("strftime('%Y-%W', memories.created_at)")).count
      }
    end

    # Read-only clustering of likely-duplicate memories (by shared tags + title
    # similarity). Suggestions only — merging stays a human decision.
    def suggest_merge_candidates(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])
      min_score = args["min_score"].presence&.to_f

      finder = min_score ? WorkspaceMergeCandidates.new(workspace, min_score: min_score) : WorkspaceMergeCandidates.new(workspace)
      finder.clusters.map do |cluster|
        {
          score: cluster.score,
          reasons: cluster.reasons,
          memories: cluster.memories.map { |memory| memory_json(memory.resolve_current_version) }
        }
      end
    end

    # Single serialization shape for a memory, mirroring the REST jbuilder
    # (app/views/memories/_memory.json.jbuilder) so the two surfaces don't drift.
    def memory_json(memory)
      {
        id: memory.root_memory.id.to_s, # stable id clients use for read/update/version
        title: memory.title,
        category: memory.category,
        tags: memory.tags,
        source: memory.source,
        version: memory.version,
        created_at: memory.created_at.iso8601,
        updated_at: memory.updated_at.iso8601
      }
    end
    private_class_method :memory_json

    def normalize_tags(value)
      Array(value).map { |tag| tag.to_s.strip }.reject(&:blank?)
    end
    private_class_method :normalize_tags

    # Raises on an invalid non-blank category so a bad filter value fails loudly
    # instead of silently returning every memory (by_category no-ops on unknown
    # values). Blank is allowed — it means "no category filter".
    def validate_category!(category)
      return if category.blank?
      return if Memory::CATEGORIES.include?(category)

      raise ToolError, "Invalid category: #{category}"
    end
    private_class_method :validate_category!

    def clamp_limit(value)
      limit = value.to_i
      limit = LIST_DEFAULT_LIMIT if limit < 1
      [limit, LIST_MAX_LIMIT].min
    end
    private_class_method :clamp_limit

    # Tag frequency across a relation of memories, most common first. Reads tags
    # in Ruby because they're a serialized JSON array, not a queryable column.
    def top_tags(relation, limit = 20)
      counts = Hash.new(0)
      relation.pluck(:tags).each do |tags|
        tags = parse_tags(tags)
        tags.each { |tag| counts[tag] += 1 }
      end
      counts.sort_by { |tag, count| [-count, tag] }.first(limit).map { |tag, count| {tag: tag, count: count} }
    end
    private_class_method :top_tags

    # pluck bypasses the serialize coder, so a JSON-array column can come back as a
    # raw string; normalize both shapes to an array.
    def parse_tags(value)
      value = JSON.parse(value) if value.is_a?(String)
      Array(value)
    rescue JSON::ParserError
      []
    end
    private_class_method :parse_tags

    def find_workspace(account, workspace_id)
      account.workspaces.active.find_by(id: workspace_id) ||
        raise(ToolError, "Workspace not found")
    end
    private_class_method :find_workspace

    def find_memory(account, memory_id)
      Memory.joins(:workspace)
        .where(workspaces: {account_id: account.id})
        .latest_versions
        .find_by(id: memory_id) ||
        raise(ToolError, "Memory not found")
    end
    private_class_method :find_memory
  end
end
