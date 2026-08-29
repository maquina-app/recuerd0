# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
require "rouge/plugins/redcarpet"

class MarkdownRenderer < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet

  # heading_offset shifts every rendered heading down by N levels. Content
  # embedded in a page that already owns the <h1> passes 1; a standalone
  # document rendered on its own (the downloadable SKILL.md) passes 0 and keeps
  # its real <h1>.
  def self.build(heading_offset: 0)
    renderer = MarkdownRenderer.new(ActionText::Markdown::DEFAULT_RENDERER_OPTIONS)
    renderer.heading_offset = heading_offset
    Redcarpet::Markdown.new(renderer, ActionText::Markdown::DEFAULT_MARKDOWN_EXTENSIONS)
  end

  attr_accessor :heading_offset

  def initialize(*args)
    super
    @id_counts = Hash.new(0)
    @heading_offset = 0
  end

  # A memory whose Markdown opens with "# Title" used to emit a second <h1> with
  # the same text as the page heading — a heading-structure violation and the
  # largest text on screen. heading_offset fixes that for embedded content
  # without touching standalone documents. h6 has nowhere to go and stays put.
  #
  # The anchor is aria-hidden, so it must also leave the tab order: aria-hidden
  # on a focusable element leaves a stop that announces nothing (five of them,
  # before the first real link, on a typical memory).
  def header(text, header_level)
    level = [header_level + heading_offset, 6].min
    unique_id(text).then do |id|
      escaped_id = ERB::Util.html_escape(id)
      "<h#{level} id='#{escaped_id}'>#{text} <a href='##{escaped_id}' class='heading__link' aria-hidden='true' tabindex='-1'>#</a></h#{level}>"
    end
  end

  # Wraps each image in a lightbox-ready link. The `data-action` hook is a no-op
  # unless the host app registers a Stimulus `lightbox` controller — wire one up
  # (or strip the data attributes) to taste.
  def image(url, title, alt_text)
    safe_url = ERB::Util.html_escape(url)
    safe_title = ERB::Util.html_escape(title)
    safe_alt = ERB::Util.html_escape(alt_text)
    %(<a href="#{safe_url}" title="#{safe_title}" data-action="lightbox#open:prevent" data-lightbox-target="image" data-lightbox-url-value="#{safe_url}?disposition=inline"><img src="#{safe_url}" alt="#{safe_alt}" loading="lazy" decoding="async"></a>)
  end

  private

  def unique_id(text)
    text.parameterize.then do |base_id|
      @id_counts[base_id] += 1
      (@id_counts[base_id] > 1) ? "#{base_id}-#{@id_counts[base_id]}" : base_id
    end
  end
end
