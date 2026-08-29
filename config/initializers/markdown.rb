ActiveSupport.on_load :action_text_markdown do
  require "markdown_renderer"
  # Memory content always renders inside a page that owns the <h1>, so shift its
  # headings down one level.
  ActionText::Markdown.renderer = -> { MarkdownRenderer.build(heading_offset: 1) }
end
