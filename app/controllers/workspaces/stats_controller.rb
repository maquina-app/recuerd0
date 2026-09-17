class Workspaces::StatsController < ApplicationController
  include ObsoleteFilterable

  allow_token_authentication

  before_action :set_workspace
  before_action :ensure_not_deleted

  # GET /workspaces/:workspace_id/stats.json
  #
  # Aggregate rollup computed server-side so callers get counts and trends
  # without paging the full memory list. Mirrors the workspace_stats MCP tool.
  def show
    roots = apply_obsolete_filter(@workspace.memories.latest_versions)

    @total_memories = roots.count
    # Version rows are counted through their root's visibility: a figure that
    # spans versions has no other coherent reading of "excludes obsolete".
    @total_versions = version_rows(roots).count
    @counts_by_category = Memory::CATEGORIES.index_with { 0 }.merge(roots.group(:category).count)
    @top_tags = top_tags(roots)
    @memories_by_week = roots.group(Arel.sql("strftime('%Y-%W', memories.created_at)")).count

    workspace_memory_ids = version_rows(roots).select(:id)
    @total_links = MemoryLink
      .where(from_memory_id: workspace_memory_ids)
      .or(MemoryLink.where(to_memory_id: workspace_memory_ids))
      .count
  end

  private

  # Every memory row (root or version) whose root is visible.
  def version_rows(roots)
    @workspace.memories.where(
      "memories.id IN (:roots) OR memories.parent_memory_id IN (:roots)",
      roots: roots.select(:id)
    )
  end

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id])
  end

  def ensure_not_deleted
    render_not_found if @workspace.deleted?
  end

  # Tags are a serialized JSON array, not a queryable column, so tally in Ruby.
  def top_tags(relation, limit = 20)
    counts = Hash.new(0)
    relation.pluck(:tags).each do |tags|
      tags = JSON.parse(tags) if tags.is_a?(String)
      Array(tags).each { |tag| counts[tag] += 1 }
    rescue JSON::ParserError
      next
    end
    counts.sort_by { |tag, count| [-count, tag] }.first(limit).map { |tag, count| {tag: tag, count: count} }
  end
end
