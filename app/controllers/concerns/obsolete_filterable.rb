# Obsolete memories (tagged obsolete/superseded/deprecated) are hidden from
# retrieval by default; `?include=obsolete` brings them back. Memories living in
# an archived or soft-deleted workspace are hidden the same way, behind
# `?include=inactive`. Shaped like MemoryFilterable: private helpers, param
# parsing, scope in / scope out.
module ObsoleteFilterable
  extend ActiveSupport::Concern

  OBSOLETE_TOKEN = "obsolete".freeze
  INACTIVE_TOKEN = "inactive".freeze

  included do
    helper_method :include_obsolete?, :include_inactive?, :query_params_including
  end

  private

  # Comma-separated list, stripped and downcased. Unrecognized tokens are
  # ignored rather than rejected, so adding a token later can never break a
  # client that already sends one.
  #
  # An array is accepted too: the search page renders one check_box_tag per
  # token, all named `include`, so the browser submits
  # `include=obsolete&include=inactive` rather than one comma string.
  def include_tokens
    Array(params[:include])
      .flat_map { |value| value.to_s.split(",") }
      .map { |token| token.strip.downcase }
      .reject(&:blank?)
  end

  def include_obsolete?
    include_tokens.include?(OBSOLETE_TOKEN)
  end

  def include_inactive?
    include_tokens.include?(INACTIVE_TOKEN)
  end

  # The current query with one more token switched on, for the "N hidden" links.
  # Merging a bare string would drop a token the caller already sent, so the two
  # withheld-notice links can't undo each other. Emitted as the comma form, so a
  # single token still yields the plain `?include=obsolete` URL.
  def query_params_including(token)
    request.query_parameters.merge("include" => (include_tokens | [token]).join(","))
  end

  def apply_obsolete_filter(scope)
    include_obsolete? ? scope : scope.without_obsolete
  end

  # Archived and soft-deleted workspaces both count as inactive: a memory from a
  # project that was shut down should not reach a context window by accident.
  def apply_inactive_filter(scope)
    include_inactive? ? scope : scope.in_active_workspaces
  end
end
