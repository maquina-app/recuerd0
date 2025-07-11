# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Clear existing data (optional, useful for development)
puts "Cleaning database..."
Workspace.destroy_all
User.destroy_all

# Create a user
puts "Creating user..."
user = User.create!(
  email_address: "demo@recuerd0.com",
  password: "p4$$w0rd",
  password_confirmation: "p4$$w0rd"
)

# Create workspaces for the user
puts "Creating workspaces..."
workspace1 = Workspace.create!(
  name: "AI Research Notes",
  description: "Collection of interesting AI conversations and insights",
  user: user
)

workspace2 = Workspace.create!(
  name: "Project Ideas",
  description: "Brainstorming sessions and project planning discussions",
  user: user
)

puts "Seeding completed!"
puts "Created:"
puts "- 1 user (email: demo@recuerd0.com, password: password123)"
puts "- 2 workspaces: '#{workspace1.name}' and '#{workspace2.name}'"
