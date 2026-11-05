module ApiHelpers
  extend ActiveSupport::Concern

  class InvalidPage < StandardError; end

  # Far past any real list, and well short of the offset overflowing SQLite's integer.
  MAX_PAGE = 1_000_000_000_000

  private

  # Pagy's default sends a page past the end back to the last page, which suits a
  # person clicking around and traps a client that loops until it gets an empty
  # page. API requests get that empty page.
  def pagy(collection, **vars)
    vars[:overflow] = :empty_page if api_request?
    vars[:page] ||= requested_page
    super
  end

  # A bad page is a mistake an API client should hear about. A person who followed
  # a bad link just gets the first page.
  def requested_page
    page = params[:page]
    return 1 if page.blank?
    return page.to_i if page.is_a?(String) && page.match?(/\A[1-9]\d*\z/) && page.to_i <= MAX_PAGE
    raise InvalidPage if api_request?

    1
  end

  def set_pagination_headers(pagy)
    headers["X-Page"] = pagy.page.to_s
    headers["X-Per-Page"] = pagy.limit.to_s
    headers["X-Total"] = pagy.count.to_s
    headers["X-Total-Pages"] = pagy.pages.to_s
    headers["Link"] = pagination_link_header(pagy)
  end

  def pagination_link_header(pagy)
    links = []
    base_url = request.path
    extra = request.query_parameters.except("page").to_query
    joiner = extra.present? ? "#{extra}&" : ""

    links << %(<#{base_url}?#{joiner}page=1>; rel="first")
    links << %(<#{base_url}?#{joiner}page=#{pagy.prev}>; rel="prev") if pagy.prev
    links << %(<#{base_url}?#{joiner}page=#{pagy.next}>; rel="next") if pagy.next
    links << %(<#{base_url}?#{joiner}page=#{pagy.pages}>; rel="last")

    links.join(", ")
  end

  def render_validation_errors(record)
    render json: {
      error: {
        code: "VALIDATION_ERROR",
        message: record.errors.full_messages.to_sentence,
        details: record.errors.to_hash,
        status: 422
      }
    }, status: :unprocessable_entity
  end

  def render_validation_error(message)
    render json: {
      error: {code: "VALIDATION_ERROR", message: message, status: 422}
    }, status: :unprocessable_entity
  end

  # details is keyed by field, as render_validation_errors does for a record.
  def render_field_errors(details)
    render json: {
      error: {
        code: "VALIDATION_ERROR",
        message: details.map { |field, messages| "#{field} #{messages.to_sentence}" }.to_sentence,
        details: details,
        status: 422
      }
    }, status: :unprocessable_entity
  end

  def render_bad_request(message)
    render json: {
      error: {code: "BAD_REQUEST", message: message, status: 400}
    }, status: :bad_request
  end

  def render_not_acceptable(message = "This endpoint has no JSON representation")
    render json: {
      error: {code: "NOT_ACCEPTABLE", message: message, status: 406}
    }, status: :not_acceptable
  end

  def render_not_found(message = "Resource not found")
    render json: {
      error: {code: "NOT_FOUND", message: message, status: 404}
    }, status: :not_found
  end

  def render_rate_limited
    response.set_header("Retry-After", "60")
    render json: {
      error: {code: "RATE_LIMITED", message: "Too many requests", status: 429}
    }, status: :too_many_requests
  end

  def render_unauthorized(message = "Invalid or missing access token")
    render json: {
      error: {code: "UNAUTHORIZED", message: message, status: 401}
    }, status: :unauthorized
  end

  def render_forbidden(message = "Insufficient permissions")
    render json: {
      error: {code: "FORBIDDEN", message: message, status: 403}
    }, status: :forbidden
  end
end
