module ContentRenderable
  extend ActiveSupport::Concern

  MAX_CONTEXT_LINES = 10

  private

  def grep_mode?
    params[:mode] == "grep"
  end

  def parse_grep_params
    @grep_mode = true
    @grep_query = params[:q].to_s.strip
    context = params[:context].to_i.clamp(0, MAX_CONTEXT_LINES)
    @before_lines = params[:before].present? ? params[:before].to_i.clamp(0, MAX_CONTEXT_LINES) : context
    @after_lines = params[:after].present? ? params[:after].to_i.clamp(0, MAX_CONTEXT_LINES) : context
  end

  def parse_line_range_params
    @line_start = params[:line_start]&.to_i
    @line_end = params[:line_end]&.to_i
  end

  def line_range_requested?
    params[:line_start].present? || params[:line_end].present?
  end

  # to_i would read "abc", 0 and -1 from the start, and a huge number overflows the
  # slice that reads the lines.
  def invalid_line_numbers?
    [params[:line_start], params[:line_end]].compact_blank.any? { |line| !line.match?(/\A[1-9]\d{0,11}\z/) }
  end

  def invalid_line_range?
    @line_start && @line_end && @line_start > @line_end
  end
end
