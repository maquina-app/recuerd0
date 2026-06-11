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

    def list_memories(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])

      memories = workspace.memories.latest_versions
      memories = memories.search(args["query"]) if args["query"].present?
      memories = memories.by_category(args["category"]) if args["category"].present?

      memories.map { |memory| memory_json(memory.resolve_current_version) }
    end

    def read_memory(account, args = {})
      memory = find_memory(account, args["memory_id"]).resolve_current_version

      memory_json(memory).merge(content: memory.content&.body&.content.to_s)
    end

    def create_memory(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])
      category = args["category"].presence || Memory::DEFAULT_CATEGORY
      unless Memory::CATEGORIES.include?(category)
        raise ToolError, "Invalid category: #{category}"
      end

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
        unless Memory::CATEGORIES.include?(args["category"])
          raise ToolError, "Invalid category: #{args["category"]}"
        end
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
      category = args["category"].presence
      if category && !Memory::CATEGORIES.include?(category)
        raise ToolError, "Invalid category: #{category}"
      end

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
