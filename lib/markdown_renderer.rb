# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
require "rouge/plugins/redcarpet"

class MarkdownRenderer < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet

  def self.build
    renderer = MarkdownRenderer.new(ActionText::Markdown::DEFAULT_RENDERER_OPTIONS)
    Redcarpet::Markdown.new(renderer, ActionText::Markdown::DEFAULT_MARKDOWN_EXTENSIONS)
  end

  def initialize(*args)
    super
    @id_counts = Hash.new(0)
  end

  def header(text, header_level)
    unique_id(text).then do |id|
      escaped_id = ERB::Util.html_escape(id)
      "<h#{header_level} id='#{escaped_id}'>#{text} <a href='##{escaped_id}' class='heading__link' aria-hidden='true'>#</a></h#{header_level}>"
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
