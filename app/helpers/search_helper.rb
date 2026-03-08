module SearchHelper
  def memory_snippet(memory, length: 200)
    plain = Content.strip_markdown(memory.content&.body.to_s)
      .gsub(/\n+/, " ").squish
    truncate(plain, length: length, omission: "...")
  end
end
