module SearchHelper
  def memory_snippet(memory, length: 200)
    plain = strip_markdown(memory.content&.body.to_s)
      .gsub(/\n+/, " ").squish
    truncate(plain, length: length, omission: "...")
  end

  def strip_markdown(text)
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
end
