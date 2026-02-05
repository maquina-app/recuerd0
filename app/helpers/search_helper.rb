module SearchHelper
  def memory_snippet(memory, length: 200)
    body = memory.content&.body.to_s
    plain = body.gsub(/[#*_`~\[\]()>|\\-]/, "").gsub(/\n+/, " ").squish
    truncate(plain, length: length, omission: "...")
  end
end
