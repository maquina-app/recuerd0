module HouseMdHelper
  UNLINKED_ANCHOR = /<a(?![^>]*\shref=)[\s>]/
  LEADING_HEADING = /\A\s*<h[1-6]/

  # The memory page already shows the title, so a body opening with the same words
  # as a heading would say them twice. The stored Markdown keeps it.
  def memory_body_html(memory)
    html = sanitize_content(memory.content.body.to_html)
    return html unless html.match?(LEADING_HEADING)

    fragment = Nokogiri::HTML5.fragment(html)
    heading = fragment.element_children.first
    # The renderer appends a "#" anchor link to every heading.
    heading_text = heading.children.reject { |node| node["class"] == "heading__link" }.map(&:text).join.strip
    return html unless heading_text.casecmp?(memory.title.to_s.strip)

    heading.remove
    fragment.to_html.html_safe
  end

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
