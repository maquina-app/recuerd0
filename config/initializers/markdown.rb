ActiveSupport.on_load :action_text_markdown do
  require "markdown_renderer"
  ActionText::Markdown.renderer = -> { MarkdownRenderer.build }
end
