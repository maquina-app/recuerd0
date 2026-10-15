module SearchHelper
  # The workspace the ⌘K palette should offer to scope to. Controllers that
  # operate inside a workspace expose it as @workspace; a scoped /search exposes
  # scoped_workspace, so ⌘K there keeps the page's scope instead of silently
  # searching the whole account. Everywhere else the palette stays account-wide.
  # Guarded rather than assumed because the layout renders on every page,
  # including ones that never set either.
  def palette_scope_workspace
    workspace = @workspace if defined?(@workspace)
    workspace ||= scoped_workspace if respond_to?(:scoped_workspace)
    return nil unless workspace.is_a?(Workspace) && workspace.persisted?
    workspace
  end

  # What the results page says to a screen reader after each debounced search.
  # Blank before a query, so opening the page announces nothing.
  def search_status_message(query:, count:, workspace: nil)
    if query.blank?
      ""
    elsif query.length < Searchable::MIN_QUERY_LENGTH
      t("search.index.min_length_title")
    elsif count.positive?
      workspace ?
        t("search.index.results_count_scoped", count:, query:, workspace: workspace.name) :
        t("search.index.results_count", count:, query:)
    else
      workspace ?
        t("search.index.no_results_title_scoped", query:, workspace: workspace.name) :
        t("search.index.no_results_title")
    end
  end

  def memory_snippet(memory, length: 200)
    plain = Content.strip_markdown(memory.content&.body&.content.to_s)
      .gsub(/\n+/, " ").squish
    truncate(plain, length: length, omission: "...")
  end
end
