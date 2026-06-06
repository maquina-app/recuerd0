module HouseMdHelper
  def sanitize_content(content)
    sanitize content, scrubber: HtmlScrubber.new
  end
end
