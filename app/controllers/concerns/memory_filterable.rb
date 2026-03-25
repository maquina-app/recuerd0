module MemoryFilterable
  extend ActiveSupport::Concern

  ALLOWED_SORT_FIELDS = %w[updated_at created_at title].freeze
  ALLOWED_DIRECTIONS = %w[asc desc].freeze
  MAX_PER_PAGE = 100
  DEFAULT_PER_PAGE = 25

  private

  def apply_memory_filters(scope)
    scope = apply_title_filter(scope, params[:title])
    scope = apply_tags_filter(scope, params[:tags])
    scope = apply_source_filter(scope, params[:source])
    apply_sorting(scope)
  end

  def apply_title_filter(scope, pattern)
    return scope if pattern.blank?

    like_pattern = pattern.gsub("*", "%").gsub("?", "_")
    scope.where("LOWER(memories.title) LIKE LOWER(?)", like_pattern)
  end

  def apply_tags_filter(scope, tags_param)
    return scope if tags_param.blank?

    tags = tags_param.split(",").map(&:strip).reject(&:blank?)
    return scope if tags.empty?

    tags.each do |tag|
      scope = scope.where("EXISTS (SELECT 1 FROM json_each(memories.tags) WHERE json_each.value = ?)", tag)
    end
    scope
  end

  def apply_source_filter(scope, source)
    return scope if source.blank?

    scope.where(source: source)
  end

  def apply_sorting(scope)
    field = ALLOWED_SORT_FIELDS.include?(params[:sort]) ? params[:sort] : "updated_at"
    direction = ALLOWED_DIRECTIONS.include?(params[:direction]) ? params[:direction].to_sym : :desc
    scope.reorder(Arel.sql("memories.#{field}") => direction)
  end

  def permitted_per_page
    per_page = params[:per_page].to_i
    per_page = DEFAULT_PER_PAGE if per_page < 1
    [per_page, MAX_PER_PAGE].min
  end
end
