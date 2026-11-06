module MemoryFilterable
  extend ActiveSupport::Concern

  ALLOWED_SORT_FIELDS = %w[updated_at created_at title].freeze
  ALLOWED_DIRECTIONS = %w[asc desc].freeze
  MAX_PER_PAGE = 100
  DEFAULT_PER_PAGE = 25

  private

  # A category outside the vocabulary used to sail through as "no filter"
  # (by_category no-ops on an unknown value), so a typo returned every memory
  # and read as a filtered set. JSON callers get a 422 instead; HTML surfaces
  # keep the silent presence_in behaviour. Returns false once it has rendered,
  # so a caller can `return unless validate_category_param!`.
  def validate_category_param!
    category = params[:category]
    return true if category.blank? || Memory::CATEGORIES.include?(category)

    render_validation_error("Invalid category: #{category}")
    false
  end

  # The same for sort and direction, which used to fall back to the default order
  # and read as if the request had been honoured.
  def validate_sort_params!
    if params[:sort].present? && ALLOWED_SORT_FIELDS.exclude?(params[:sort])
      render_validation_error("Invalid sort: #{params[:sort]}. Use #{ALLOWED_SORT_FIELDS.to_sentence(last_word_connector: " or ", two_words_connector: " or ")}")
      return false
    end
    return true if params[:direction].blank? || ALLOWED_DIRECTIONS.include?(params[:direction])

    render_validation_error("Invalid direction: #{params[:direction]}. Use asc or desc")
    false
  end

  def apply_memory_filters(scope)
    scope = apply_title_filter(scope, params[:title])
    scope = apply_tags_filter(scope, params[:tags])
    scope = apply_source_filter(scope, params[:source])
    scope = scope.by_category(params[:category])
    apply_sorting(scope)
  end

  def apply_title_filter(scope, pattern)
    return scope if pattern.blank?

    # Only * and ? are wildcards here; a % or _ in the pattern means itself.
    like_pattern = ActiveRecord::Base.sanitize_sql_like(pattern).gsub("*", "%").gsub("?", "_")
    scope.with_current_title_like(like_pattern)
  end

  def apply_tags_filter(scope, tags_param)
    return scope if tags_param.blank?

    tags = tags_param.split(",").map(&:strip).reject(&:blank?)
    return scope if tags.empty?

    tags.each do |tag|
      scope = scope.where("EXISTS (SELECT 1 FROM json_each(memories.tags) WHERE json_each.value = ? COLLATE NOCASE)", tag)
    end
    scope
  end

  def apply_source_filter(scope, source)
    return scope if source.blank?

    scope.with_current_source(source)
  end

  def apply_sorting(scope)
    field = ALLOWED_SORT_FIELDS.include?(params[:sort]) ? params[:sort] : "updated_at"
    direction = ALLOWED_DIRECTIONS.include?(params[:direction]) ? params[:direction].to_sym : :desc
    column = (field == "title") ? Memory::CURRENT_TITLE_SQL : "memories.#{field}"
    scope.reorder(Arel.sql(column) => direction)
  end

  def permitted_per_page
    per_page = params[:per_page].to_i
    per_page = DEFAULT_PER_PAGE if per_page < 1
    [per_page, MAX_PER_PAGE].min
  end
end
