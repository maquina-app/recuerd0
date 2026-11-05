# A line-level diff between two versions of a memory: what changed, with a line of
# context either side, and runs of unchanged lines collapsed into a gap.
class LineDiff
  Line = Struct.new(:kind, :text)

  CONTEXT = 1
  # Beyond this the longest-common-subsequence table gets expensive. The changed
  # block is then shown as removed and added whole, which is coarser but true.
  MAX_TABLE_CELLS = 250_000

  def initialize(old_text, new_text)
    @old_lines = old_text.to_s.split("\n", -1)
    @new_lines = new_text.to_s.split("\n", -1)
  end

  def lines
    @lines ||= collapse(edits)
  end

  def added_count
    edits.count { |line| line.kind == :added }
  end

  def removed_count
    edits.count { |line| line.kind == :removed }
  end

  def changed?
    added_count.positive? || removed_count.positive?
  end

  private

  def edits
    @edits ||= begin
      head = common_prefix_length
      tail = common_suffix_length(head)
      old_middle = @old_lines[head...(@old_lines.size - tail)]
      new_middle = @new_lines[head...(@new_lines.size - tail)]

      unchanged(@old_lines.first(head)) +
        diff_middle(old_middle, new_middle) +
        unchanged(@old_lines.last(tail))
    end
  end

  def common_prefix_length
    limit = [@old_lines.size, @new_lines.size].min
    (0...limit).take_while { |i| @old_lines[i] == @new_lines[i] }.size
  end

  def common_suffix_length(head)
    limit = [@old_lines.size, @new_lines.size].min - head
    (0...limit).take_while { |i| @old_lines[-1 - i] == @new_lines[-1 - i] }.size
  end

  def diff_middle(old_lines, new_lines)
    if old_lines.size * new_lines.size > MAX_TABLE_CELLS
      return old_lines.map { |text| Line.new(:removed, text) } + new_lines.map { |text| Line.new(:added, text) }
    end

    table = Array.new(old_lines.size + 1) { Array.new(new_lines.size + 1, 0) }
    old_lines.size.downto(1) do |i|
      new_lines.size.downto(1) do |j|
        table[i - 1][j - 1] = if old_lines[i - 1] == new_lines[j - 1]
          table[i][j] + 1
        else
          [table[i][j - 1], table[i - 1][j]].max
        end
      end
    end

    walk(table, old_lines, new_lines)
  end

  def walk(table, old_lines, new_lines)
    result = []
    i = j = 0

    while i < old_lines.size || j < new_lines.size
      if i < old_lines.size && j < new_lines.size && old_lines[i] == new_lines[j]
        result << Line.new(:unchanged, old_lines[i])
        i += 1
        j += 1
      elsif j < new_lines.size && (i == old_lines.size || table[i][j + 1] > table[i + 1][j])
        result << Line.new(:added, new_lines[j])
        j += 1
      else
        result << Line.new(:removed, old_lines[i])
        i += 1
      end
    end

    result
  end

  def unchanged(lines)
    lines.map { |text| Line.new(:unchanged, text) }
  end

  def collapse(all)
    keep = Array.new(all.size, false)
    all.each_with_index do |line, index|
      next if line.kind == :unchanged

      ([index - CONTEXT, 0].max..[index + CONTEXT, all.size - 1].min).each { |near| keep[near] = true }
    end

    all.each_with_index.with_object([]) do |(line, index), output|
      if keep[index]
        output << line
      elsif output.last&.kind != :gap
        output << Line.new(:gap, nil)
      end
    end
  end
end
