module HouseMdHelper
  UNLINKED_ANCHOR = /<a(?![^>]*\shref=)[\s>]/

  # The sanitizer drops an unsafe href (javascript:) but keeps the <a>, which
  # still looks like a link and does nothing. Those render as plain text.
  def sanitize_content(content)
    clean = sanitize(content, scrubber: HtmlScrubber.new).to_s
    return clean.html_safe unless clean.match?(UNLINKED_ANCHOR)

    fragment = Nokogiri::HTML5.fragment(clean)
    fragment.css("a:not([href])").each { |anchor| anchor.replace(anchor.children) }
    fragment.to_html.html_safe
  end
end
