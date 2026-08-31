require "test_helper"

# The workspaces filter used to be the only input suppressing WebKit's native
# clear "X", because the rule was scoped to .ws-filter. Every other search input
# — the memories toolbar, the link picker, the search page, the palette — grew
# the X the moment it held a value. One unscoped rule keeps them identical.
class SearchInputCssTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/tailwind/application.css")

  test "the native search clear button is suppressed for every search input" do
    css = STYLESHEET.read

    assert_match(/^input\[type="search"\]::-webkit-search-cancel-button \{/, css)
    assert_equal 1, css.scan("::-webkit-search-cancel-button").size,
      "expected exactly one cancel-button rule; a class-scoped copy means some " \
      "search inputs keep the X and others do not"
  end
end
