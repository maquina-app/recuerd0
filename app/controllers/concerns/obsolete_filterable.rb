# Obsolete memories (tagged obsolete/superseded/deprecated) are hidden from
# retrieval by default; `?include=obsolete` brings them back. Shaped like
# MemoryFilterable: private helpers, param parsing, scope in / scope out.
module ObsoleteFilterable
  extend ActiveSupport::Concern

  OBSOLETE_TOKEN = "obsolete".freeze

  included do
    helper_method :include_obsolete?
  end

  private

  # Comma-separated list, stripped and downcased. Unrecognized tokens are
  # ignored rather than rejected, so adding a token later can never break a
  # client that already sends one.
  def include_tokens
    params[:include].to_s.split(",").map { |token| token.strip.downcase }.reject(&:blank?)
  end

  def include_obsolete?
    include_tokens.include?(OBSOLETE_TOKEN)
  end

  def apply_obsolete_filter(scope)
    include_obsolete? ? scope : scope.without_obsolete
  end
end
