# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
class HtmlScrubber < Rails::Html::PermitScrubber
  def initialize
    super
    self.tags = Rails::Html::WhiteListSanitizer.allowed_tags + %w[
      audio details summary iframe options table tbody td th thead tr video source mark
    ]
  end
end
