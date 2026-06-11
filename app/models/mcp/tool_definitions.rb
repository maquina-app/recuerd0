module Mcp
  # JSON-Schema definitions advertised via tools/list. Names must match the
  # public methods on Mcp::Tools.
  module ToolDefinitions
    CATEGORIES = Memory::CATEGORIES

    ALL = [
      {
        name: "list_workspaces",
        description: "List all workspaces belonging to the authenticated user.",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {type: "object", properties: {}, required: []}
      },
      {
        name: "list_memories",
        description: "List memories within a workspace. Supports optional FTS5 query filtering.",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            workspace_id: {type: "string", description: "Workspace ID"},
            query: {type: "string", description: "Optional FTS5 search query"},
            category: {type: "string", enum: CATEGORIES, description: "Filter by memory category"}
          },
          required: ["workspace_id"]
        }
      },
      {
        name: "read_memory",
        description: "Read the full content of a single memory by ID.",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {memory_id: {type: "string", description: "Memory ID"}},
          required: ["memory_id"]
        }
      },
      {
        name: "create_memory",
        description: "Create a new memory in a workspace.",
        annotations: {readOnlyHint: false, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            workspace_id: {type: "string"},
            title: {type: "string"},
            content: {type: "string"},
            category: {type: "string", enum: CATEGORIES}
          },
          required: %w[workspace_id title content]
        }
      },
      {
        name: "update_memory",
        description: "Update the content or title of an existing memory.",
        annotations: {readOnlyHint: false, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            memory_id: {type: "string"},
            title: {type: "string"},
            content: {type: "string"}
          },
          required: ["memory_id"]
        }
      }
    ].freeze

    NAMES = ALL.map { |tool| tool[:name] }.freeze

    def self.exists?(name)
      NAMES.include?(name)
    end
  end
end
