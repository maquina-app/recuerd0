class Content < ApplicationRecord
  belongs_to :memory, touch: true

  # Stores the raw markdown in a sibling action_text_markdowns row.
  # `body` returns the ActionText::Markdown record (.content is the raw string,
  # .to_html renders); `body = "..."` accepts a String.
  has_markdown :body

  after_save_commit :reindex_memory

  def self.strip_markdown(text)
    text
      .gsub(/^\#{1,6}\s+/, "")       # headings: "## Title" → "Title"
      .gsub(/(\*{1,3}|_{1,3})(\S.*?\S)\1/, '\2') # bold/italic wrapping
      .gsub(/~~(.*?)~~/, '\1')        # strikethrough
      .gsub(/`{1,3}([^`]*)`{1,3}/, '\1') # inline code / code blocks
      .gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\1') # links/images: [text](url) → text
      .gsub(/^\s*>+\s?/, "")          # blockquotes
      .gsub(/^\s*[-*+]\s+/, "")       # unordered list markers
      .gsub(/^\s*\d+\.\s+/, "")       # ordered list markers
      .gsub(/^---+$/, "")             # horizontal rules
      .gsub(/^\|.*\|$/m, "")          # table rows
  end

  def plain_text
    self.class.strip_markdown(body.content.to_s)
  end

  private

  def reindex_memory
    memory.rebuild_search_index if memory.respond_to?(:rebuild_search_index)
  end
end
