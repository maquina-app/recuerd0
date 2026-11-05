require "test_helper"

# Every confirmation goes through the app's own dialog (Turbo.config.forms.confirm), so
# it looks and behaves the same everywhere. The browser's dialogs also block the page.
# beforeunload is the one exception, and it isn't a call this would match: pages can't
# replace that prompt.
class NoNativeDialogsTest < ActiveSupport::TestCase
  NATIVE_DIALOG = /window\.(confirm|alert|prompt)\b|(?<![.\w#])(confirm|alert|prompt)\(/

  test "no app JavaScript opens a native dialog" do
    offenders = Rails.root.glob("app/javascript/**/*.js").flat_map do |path|
      path.readlines.each_with_index.filter_map do |line, index|
        next if line.lstrip.start_with?("//")

        "#{path.relative_path_from(Rails.root)}:#{index + 1}: #{line.strip}" if line.match?(NATIVE_DIALOG)
      end
    end

    assert_empty offenders, "Use Turbo.config.forms.confirm instead of a native dialog"
  end
end
