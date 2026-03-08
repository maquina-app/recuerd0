class ErrorsController < ApplicationController
  allow_unauthenticated_access

  layout false

  def bad_request
    respond_to do |format|
      format.json { render json: error_json("BAD_REQUEST", t("errors.bad_request"), 400), status: :bad_request }
      format.all { render html: static_page("400"), status: :bad_request, content_type: "text/html" }
    end
  end

  def not_found
    respond_to do |format|
      format.json { render json: error_json("NOT_FOUND", t("errors.not_found"), 404), status: :not_found }
      format.all { render html: static_page("404"), status: :not_found, content_type: "text/html" }
    end
  end

  def unprocessable_entity
    respond_to do |format|
      format.json { render json: error_json("UNPROCESSABLE_ENTITY", t("errors.unprocessable_entity"), 422), status: :unprocessable_entity }
      format.all { render html: static_page("422"), status: :unprocessable_entity, content_type: "text/html" }
    end
  end

  def internal_server_error
    respond_to do |format|
      format.json { render json: error_json("INTERNAL_SERVER_ERROR", t("errors.internal_server_error"), 500), status: :internal_server_error }
      format.all { render html: static_page("500"), status: :internal_server_error, content_type: "text/html" }
    end
  end

  private

  def error_json(code, message, status)
    {error: {code: code, message: message, status: status}}
  end

  def static_page(code)
    Rails.root.join("public", "#{code}.html").read.html_safe
  end
end
