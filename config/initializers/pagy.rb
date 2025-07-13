# config/initializers/pagy.rb
require "pagy/extras/overflow"

# Handle overflow by showing the last page
Pagy::DEFAULT[:overflow] = :last_page

# Default items per page
Pagy::DEFAULT[:limit] = 10

# Control how many page links are shown
# The size can be a single number or an array for responsive behavior
# Format: [start_links, before_current, current, after_current, end_links]
# Example: [1, 4, 4, 4, 1] means:
# - 1 link at the start
# - 4 links before current page
# - 4 links after current page
# - 1 link at the end
Pagy::DEFAULT[:size] = 7  # [1, 4, 4, 4, 1]
