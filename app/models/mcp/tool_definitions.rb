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
        description: "List memories within a workspace. Supports optional FTS5 query " \
          "filtering and category filtering. Returns a paginated envelope: " \
          "{memories, total_count, has_more, next_offset}. Pass `offset: next_offset` " \
          "to fetch the following page. Defaults to 50 per page (max 200).",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            workspace_id: {type: "string", description: "Workspace ID"},
            query: {type: "string", description: "Optional FTS5 search query"},
            category: {type: "string", enum: CATEGORIES, description: "Filter by memory category"},
            sort: {type: "string", enum: %w[updated created title],
                   description: "Sort order (default: updated, newest first)"},
            limit: {type: "integer", description: "Page size, 1–200 (default 50)"},
            offset: {type: "integer", description: "Rows to skip (default 0)"}
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
        name: "read_memories",
        description: "Read several memories (with content) in a single call. Returns " \
          "{memories, missing} — unknown or out-of-account IDs are listed in `missing` " \
          "rather than failing the call. Up to 50 IDs per call.",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            memory_ids: {type: "array", items: {type: "string"}, description: "Memory IDs (max 50)"}
          },
          required: ["memory_ids"]
        }
      },
      {
        name: "list_memory_links",
        description: "List the memories linked to a given memory. Links are undirected, " \
          "unlabeled cross-workspace \"see also\" associations within your account.",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {memory_id: {type: "string", description: "Memory ID"}},
          required: ["memory_id"]
        }
      },
      {
        name: "link_memories",
        description: "Create an undirected \"see also\" link between two memories in the " \
          "same account (may be in different workspaces). Idempotent per pair.",
        annotations: {readOnlyHint: false, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            memory_id: {type: "string", description: "One memory ID"},
            to_memory_id: {type: "string", description: "The other memory ID"}
          },
          required: %w[memory_id to_memory_id]
        }
      },
      {
        name: "unlink_memories",
        description: "Remove the \"see also\" link between two memories.",
        annotations: {readOnlyHint: false, destructiveHint: true},
        inputSchema: {
          type: "object",
          properties: {
            memory_id: {type: "string", description: "One memory ID"},
            to_memory_id: {type: "string", description: "The other memory ID"}
          },
          required: %w[memory_id to_memory_id]
        }
      },
      {
        name: "create_memory",
        description: "Create a new memory in a workspace. The calling application " \
          "is recorded automatically as the memory's source.",
        annotations: {readOnlyHint: false, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            workspace_id: {type: "string"},
            title: {type: "string"},
            content: {type: "string"},
            category: {type: "string", enum: CATEGORIES},
            tags: {type: "array", items: {type: "string"},
                   description: "Optional tags for search and filtering"}
          },
          required: %w[workspace_id title content]
        }
      },
      {
        name: "update_memory",
        description: "Update an existing memory in place (title, content, category, " \
          "or tags). Does not create a new version — use create_version to preserve history.",
        annotations: {readOnlyHint: false, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            memory_id: {type: "string"},
            title: {type: "string"},
            content: {type: "string"},
            category: {type: "string", enum: CATEGORIES},
            tags: {type: "array", items: {type: "string"},
                   description: "Optional tags for search and filtering"}
          },
          required: ["memory_id"]
        }
      },
      {
        name: "create_version",
        description: "Append a new immutable version to an existing memory, " \
          "preserving prior versions as history. Any omitted field inherits its " \
          "value from the latest version.",
        annotations: {readOnlyHint: false, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            memory_id: {type: "string"},
            title: {type: "string"},
            content: {type: "string"},
            category: {type: "string", enum: CATEGORIES},
            tags: {type: "array", items: {type: "string"},
                   description: "Optional tags for search and filtering"}
          },
          required: ["memory_id"]
        }
      },
      {
        name: "workspace_stats",
        description: "Aggregate rollup for a workspace without shipping memory bodies: " \
          "total_memories, total_versions, counts_by_category, total_links, top_tags, " \
          "and memories_by_week. Use this instead of paging list_memories for counts/trends.",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {workspace_id: {type: "string", description: "Workspace ID"}},
          required: ["workspace_id"]
        }
      },
      {
        name: "suggest_merge_candidates",
        description: "Suggest clusters of likely-duplicate memories in a workspace, scored " \
          "by shared tags and title similarity. Read-only — it only proposes clusters; " \
          "merging stays a human decision. Returns [{score, reasons, memories}].",
        annotations: {readOnlyHint: true, destructiveHint: false},
        inputSchema: {
          type: "object",
          properties: {
            workspace_id: {type: "string", description: "Workspace ID"},
            min_score: {type: "number", description: "Similarity threshold 0–1 (default 0.5)"}
          },
          required: ["workspace_id"]
        }
      }
    ].freeze

    NAMES = ALL.map { |tool| tool[:name] }.freeze

    def self.exists?(name)
      NAMES.include?(name)
    end
  end
end
