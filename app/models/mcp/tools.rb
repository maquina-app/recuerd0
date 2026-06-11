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
          created_at: workspace.created_at.iso8601
        }
      end
    end

    def list_memories(account, args = {})
      workspace = find_workspace(account, args["workspace_id"])

      memories = workspace.memories.latest_versions
      memories = memories.search(args["query"]) if args["query"].present?
      memories = memories.by_category(args["category"]) if args["category"].present?

      memories.map do |memory|
        {
          id: memory.id.to_s,
          title: memory.display_title,
          category: memory.category,
          created_at: memory.created_at.iso8601
        }
      end
    end

    def read_memory(account, args = {})
      memory = find_memory(account, args["memory_id"])

      {
        id: memory.id.to_s,
        title: memory.title,
        category: memory.category,
        content: memory.content&.body&.content.to_s,
        created_at: memory.created_at.iso8601,
        updated_at: memory.updated_at.iso8601
      }
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
        content: args["content"]
      )
      raise ToolError, memory.errors.full_messages.to_sentence if memory.errors.any?

      {id: memory.id.to_s, title: memory.title, category: memory.category}
    end

    def update_memory(account, args = {})
      memory = find_memory(account, args["memory_id"])

      attributes = {}
      attributes[:title] = args["title"] if args["title"].present?
      attributes[:content] = args["content"] if args.key?("content")
      memory.update_with_content(attributes)
      raise ToolError, memory.errors.full_messages.to_sentence if memory.errors.any?

      {id: memory.id.to_s, title: memory.title}
    end

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
