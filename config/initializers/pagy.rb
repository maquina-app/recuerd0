# config/initializers/pagy.rb
require "pagy/extras/overflow"

# Handle overflow by showing the last page
Pagy::DEFAULT[:overflow] = :last_page

# Default items per page
Pagy::DEFAULT[:items] = 10

# The I18n is handled differently in newer versions of Pagy
# You can customize labels by creating a locale file or using the built-in defaults
