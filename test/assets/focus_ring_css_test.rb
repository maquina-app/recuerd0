require "test_helper"

# A focus ring has to reach 3:1 against what's next to it (WCAG 1.4.11). --ring at 50%
# only reached 2.23:1 in light and 2.74:1 in dark, and on these controls nothing else
# changes on focus. Compound fields keep their 50% outline because their border carries it.
class FocusRingCssTest < ActiveSupport::TestCase
  test "no box-shadow focus ring dilutes --ring" do
    css = Rails.root.join("app/assets/tailwind/application.css").read

    diluted = css.lines.each_with_index.filter_map do |line, index|
      "application.css:#{index + 1}" if line.include?("box-shadow") && line.match?(/var\(--ring\) \d+%/)
    end

    assert_empty diluted
  end
end
