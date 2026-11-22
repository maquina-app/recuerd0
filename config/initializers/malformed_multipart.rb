# Answers 400 to a multipart body Rack can't parse, before anything else reads it.
#
# Rack marks these errors Rack::BadRequest (no boundary within 16 KB, too many
# parts), but nothing on the way to a controller handles them. Rack::MethodOverride
# reads the body for `_method` and rescues the other malformed-body errors, not
# these; past it, ActionDispatch::ShowExceptions parses the body again to pick
# an error page format and fails the same way. So the error escaped the whole
# stack: production answered 500 and recorded Rack::Multipart::BoundaryTooLongError
# 44 times. Rack caches the parse in the env, so a good body isn't parsed twice.
class RejectMalformedMultipart
  BAD_REQUEST_PAGE = Rails.public_path.join("400.html")

  def initialize(app)
    @app = app
  end

  def call(env)
    return bad_request if malformed_multipart?(Rack::Request.new(env))

    @app.call(env)
  end

  private

  def malformed_multipart?(request)
    request.POST if request.media_type == "multipart/form-data"
    false
  rescue Rack::BadRequest
    true
  end

  def bad_request
    [400, {"content-type" => "text/html; charset=utf-8"}, [BAD_REQUEST_PAGE.read]]
  end
end

Rails.application.config.middleware.insert_before Rack::MethodOverride, RejectMalformedMultipart
