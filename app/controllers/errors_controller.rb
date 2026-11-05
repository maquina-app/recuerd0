class ErrorsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection # the catch-all route lets a POST in, and nothing here writes
  skip_before_action :reject_null_characters

  layout false

  def bad_request
    render_error("BAD_REQUEST", :bad_request)
  end

  def not_found
    render_error("NOT_FOUND", :not_found)
  end

  def unprocessable_entity
    render_error("UNPROCESSABLE_ENTITY", :unprocessable_entity)
  end

  def internal_server_error
    render_error("INTERNAL_SERVER_ERROR", :internal_server_error)
  end

  private

  def render_error(code, status)
    number = Rack::Utils.status_code(status)

    if json_error?
      render json: error_json(code, t("errors.#{status}"), number), status: status
    else
      render html: static_page(number), status: status, content_type: "text/html"
    end
  end

  # By the time the exceptions app runs the path is /500, so the request's format
  # no longer says it came in as /workspaces.json. The original path does.
  def json_error?
    api_request? ||
      extract_bearer_token.present? ||
      request.get_header("action_dispatch.original_path").to_s.end_with?(".json")
  end

  def error_json(code, message, status)
    {error: {code: code, message: message, status: status}}
  end

  def static_page(code)
    Rails.root.join("public", "#{code}.html").read.html_safe
  end
end
