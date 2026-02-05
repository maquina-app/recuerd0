# Create or find demo account and user
account = Account.find_or_create_by!(name: "demo")
User.find_or_create_by!(email_address: "demo@recuerd0.com") do |u|
  u.account = account
  u.password = "password123"
  u.password_confirmation = "password123"
end

# Create or find workspaces
ai_research = Workspace.find_or_create_by!(
  name: "AI Research Notes",
  account: account
) do |w|
  w.description = "Collection of interesting AI conversations and insights"
end

project_ideas = Workspace.find_or_create_by!(
  name: "Project Ideas",
  account: account
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

# Create 18 additional workspaces
additional_workspaces = [
  {name: "Ruby on Rails Tips", description: "Best practices and code snippets for Rails development"},
  {name: "Book Notes", description: "Summaries and insights from technical books"},
  {name: "Conference Talks", description: "Key takeaways from tech conferences and meetups"},
  {name: "System Design", description: "Architecture patterns and design decisions"},
  {name: "DevOps & Infrastructure", description: "Deployment strategies and infrastructure notes"},
  {name: "Frontend Development", description: "JavaScript, CSS, and modern frontend frameworks"},
  {name: "Database Optimization", description: "Query optimization and database design patterns"},
  {name: "Security Best Practices", description: "Security vulnerabilities and mitigation strategies"},
  {name: "API Design Patterns", description: "RESTful and GraphQL API design principles"},
  {name: "Testing Strategies", description: "Unit testing, integration testing, and TDD practices"},
  {name: "Performance Optimization", description: "Application performance and optimization techniques"},
  {name: "Open Source Contributions", description: "Ideas and notes for OSS contributions"},
  {name: "Learning Resources", description: "Courses, tutorials, and learning paths"},
  {name: "Career Development", description: "Professional growth and skill development"},
  {name: "Tech Stack Evaluations", description: "Comparisons and evaluations of technologies"},
  {name: "Bug Investigations", description: "Complex bugs and their solutions"},
  {name: "Code Refactoring", description: "Refactoring patterns and techniques"},
  {name: "Documentation Templates", description: "Templates for technical documentation"}
]

created_workspaces = additional_workspaces.map do |workspace_data|
  Workspace.find_or_create_by!(
    name: workspace_data[:name],
    account: account
  ) do |w|
    w.description = workspace_data[:description]
  end
end

# Add 25 memories to "Ruby on Rails Tips" workspace
rails_workspace = created_workspaces[0]
25.times do |i|
  create_or_update_memory(
    rails_workspace,
    {
      title: "Rails Tip ##{i + 1}",
      tags: ["rails", "ruby", "tip", "best-practice"],
      source: "Experience from Rails project"
    },
    "This is a valuable Rails tip about #{["controllers", "models", "views", "testing", "performance", "security", "deployment", "debugging"].sample}. It covers important aspects of Rails development and provides practical examples for better code organization and maintainability."
  )
end

# Add 25 memories to "System Design" workspace
system_design_workspace = created_workspaces[3]
25.times do |i|
  create_or_update_memory(
    system_design_workspace,
    {
      title: "Design Pattern: #{["Microservices", "Event Sourcing", "CQRS", "Saga Pattern", "Circuit Breaker", "API Gateway", "Service Mesh", "Distributed Cache"].sample} - Part #{i + 1}",
      tags: ["system-design", "architecture", "patterns", "distributed-systems"],
      source: "System Design Interview prep"
    },
    "Detailed explanation of system design concepts including scalability considerations, trade-offs, and real-world implementation examples. This pattern is particularly useful for #{["high-traffic applications", "distributed systems", "microservices architecture", "event-driven systems"].sample}."
  )
end

# Add a few memories to other workspaces
created_workspaces[1..5].each do |workspace|
  rand(2..5).times do |i|
    create_or_update_memory(
      workspace,
      {
        title: "#{workspace.name} Note #{i + 1}",
        tags: [workspace.name.downcase.gsub(/\s+/, "-"), "note"],
        source: "Personal experience"
      },
      "This is an important note about #{workspace.name.downcase}. It contains valuable insights and practical examples that can be applied in real-world scenarios."
    )
  end
end

puts "Seeded database with:"
puts "- #{User.count} user(s)"
puts "- #{Workspace.count} workspace(s)"
puts "- #{Memory.count} memory(ies) with content"
puts ""
puts "User: demo@recuerd0.com / password123"
puts ""
puts "Workspaces with 25+ memories:"
puts "- #{rails_workspace.name}: #{rails_workspace.memories.count} memories"
puts "- #{system_design_workspace.name}: #{system_design_workspace.memories.count} memories"
