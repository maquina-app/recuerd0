require "test_helper"

# Both are about one thing a browser test would show and a request test can't: an open
# row menu has to sit above every other row, or its items can't be clicked.
class RowMenuCssTest < ActiveSupport::TestCase
  CSS = Rails.root.join("app/assets/tailwind/application.css").read

  test "a deleted row fades its parts, not itself, so it can't trap its menu" do
    assert_no_match(/\.ws-row\.is-deleted\s*\{/, CSS)
    assert_no_match(/\.memory-row\.is-deleted\s*\{/, CSS)
    assert_match(/\.ws-row\.is-deleted > :not\(\.ws-row-actions\)/, CSS)
  end

  test "an open menu's row rises above the next row's actions" do
    assert_match(/\.ws-row-actions:has\(\[aria-expanded="true"\]\)\s*\{\s*z-index: 20;/, CSS)
  end
end
