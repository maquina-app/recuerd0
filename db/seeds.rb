# Create or find demo user
user = User.find_or_create_by!(email_address: "demo@recuerd0.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

# Create or find workspaces
ai_research = Workspace.find_or_create_by!(
  name: "AI Research Notes",
  user: user
) do |w|
  w.description = "Collection of interesting AI conversations and insights"
end

project_ideas = Workspace.find_or_create_by!(
  name: "Project Ideas",
  user: user
) do |w|
  w.description = "Brainstorming sessions and project planning discussions"
end

# Helper method to create or update memory with content
def create_or_update_memory(workspace, attributes, content_body)
  # Use a combination of workspace_id and title (or source if title is nil) as unique identifier
  attributes[:title] || attributes[:source] || content_body[0..50]

  memory = workspace.memories.find_or_create_by!(
    workspace: workspace,
    title: attributes[:title]
  ) do |m|
    m.tags = attributes[:tags] || []
    m.source = attributes[:source]
  end

  # Update tags and source in case they changed
  memory.update!(
    tags: attributes[:tags] || [],
    source: attributes[:source]
  )

  # Update or create content
  if memory.content
    memory.content.update!(body: content_body)
  else
    memory.create_content!(body: content_body)
  end

  memory
end

# Create memories for AI Research workspace
create_or_update_memory(
  ai_research,
  {
    title: "Understanding LLM Temperature Settings",
    tags: ["llm", "parameters", "temperature", "randomness"],
    source: "ChatGPT conversation - 2024-01-15"
  },
  "Temperature in LLMs controls the randomness of outputs. Lower values (0.1-0.3) make responses more focused and deterministic, while higher values (0.7-1.0) increase creativity and variety. For coding tasks, use low temperature; for creative writing, use higher values."
)

create_or_update_memory(
  ai_research,
  {
    title: "Prompt Engineering Best Practices",
    tags: ["prompt-engineering", "best-practices", "ai"],
    source: "Claude discussion - 2024-01-20"
  },
  "Key principles: 1) Be specific and clear, 2) Provide context and examples, 3) Break complex tasks into steps, 4) Use role-playing for better responses, 5) Iterate and refine based on outputs. Remember: clarity beats cleverness in prompts."
)

create_or_update_memory(
  ai_research,
  {
    title: "RAG vs Fine-tuning Comparison",
    tags: ["rag", "fine-tuning", "llm", "comparison"],
    source: "Technical blog post summary"
  },
  "RAG (Retrieval Augmented Generation) is better for: dynamic knowledge, cost-effectiveness, and transparency. Fine-tuning excels at: task-specific performance, response speed, and behavior modification. Hybrid approaches often work best for production systems."
)

# Create memories for Project Ideas workspace
create_or_update_memory(
  project_ideas,
  {
    title: "AI-Powered Code Review Tool",
    tags: ["project-idea", "ai", "developer-tools", "code-review"],
    source: "Brainstorming session - 2024-01-10"
  },
  "Build a VS Code extension that uses AI to provide contextual code reviews. Features: 1) Detect code smells and anti-patterns, 2) Suggest refactoring opportunities, 3) Check for security vulnerabilities, 4) Ensure consistent coding style. Integration with GitHub PRs would be valuable."
)

create_or_update_memory(
  project_ideas,
  {
    title: "Personal Knowledge Graph Builder",
    tags: ["project-idea", "knowledge-management", "graph", "visualization"],
    source: nil
  },
  "Create a tool that automatically builds a knowledge graph from various sources (notes, bookmarks, conversations). Use NLP to extract entities and relationships. Visualize connections between ideas. Could integrate with Obsidian, Notion, or be standalone. Key challenge: entity resolution across sources."
)

create_or_update_memory(
  project_ideas,
  {
    title: nil, # Testing optional title
    tags: ["quick-thought", "api-design"],
    source: "Shower thought"
  },
  "What if APIs could self-document based on actual usage patterns? Track common request/response pairs, error scenarios, and performance characteristics. Generate documentation that shows real-world examples instead of just schemas."
)

puts "Seeded database with:"
puts "- #{User.count} user(s)"
puts "- #{Workspace.count} workspace(s)"
puts "- #{Memory.count} memory(ies) with content"
puts ""
puts "User: demo@recuerd0.com / password123"
