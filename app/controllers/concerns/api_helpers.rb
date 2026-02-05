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

  def pagination_link_header(pagy)
    links = []
    base_url = request.path

    links << %(<#{base_url}?page=1>; rel="first")
    links << %(<#{base_url}?page=#{pagy.prev}>; rel="prev") if pagy.prev
    links << %(<#{base_url}?page=#{pagy.next}>; rel="next") if pagy.next
    links << %(<#{base_url}?page=#{pagy.pages}>; rel="last")

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
end
