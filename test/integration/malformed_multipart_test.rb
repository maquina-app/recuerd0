require "test_helper"

# Production logged Rack::Multipart::BoundaryTooLongError 44 times as a 500,
# from POSTs whose multipart body had no boundary within Rack's 16 KB limit.
# config/initializers/malformed_multipart.rb answers those with a 400.
class MalformedMultipartTest < ActionDispatch::IntegrationTest
  test "a multipart body without its boundary is a bad request, not an error" do
    reported = []
    subscriber = Class.new { define_method(:report) { |error, **| reported << error } }.new
    Rails.error.subscribe(subscriber)

    post session_url, params: "x" * 17.kilobytes,
      headers: {"CONTENT_TYPE" => "multipart/form-data; boundary=abc"}

    assert_response :bad_request
    assert_empty reported.grep(Rack::Multipart::BoundaryTooLongError)
  ensure
    Rails.error.unsubscribe(subscriber)
  end

  test "a well-formed multipart body still reaches the app" do
    note = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "note.txt")

    post session_url, params: {email_address: users(:one).email_address, password: "password", note: note}

    assert_equal "multipart/form-data", request.media_type
    assert_redirected_to workspaces_path
  end
end
