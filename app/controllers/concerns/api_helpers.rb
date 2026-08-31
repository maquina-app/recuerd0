module ApiHelpers
  extend ActiveSupport::Concern

  private

  def set_pagination_headers(pagy)
    headers["X-Page"] = pagy.page.to_s
    headers["X-Per-Page"] = pagy.limit.to_s
    headers["X-Total"] = pagy.count.to_s
    headers["X-Total-Pages"] = pagy.pages.to_s
    headers["Link"] = pagination_link_header(pagy)
  end

  # Hand-rolled rather than Pagy#headers_hash: that helper names its headers
  # current-page / page-limit / total-count / total-pages and its links
  # rel="previous", while docs/API.md publishes X-Page / X-Per-Page / X-Total /
  # X-Total-Pages and RFC 8288 registers "prev", not "previous". Adopting it
  # would be a breaking change to clients for no gain — it composes the same URLs
  # this does, query parameters included.
  def pagination_link_header(pagy)
    links = []
    base_url = request.path
    extra = request.query_parameters.except("page").to_query
    joiner = extra.present? ? "#{extra}&" : ""

    links << %(<#{base_url}?#{joiner}page=1>; rel="first")
    links << %(<#{base_url}?#{joiner}page=#{pagy.previous}>; rel="prev") if pagy.previous
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
