# Strong parameters quietly drops a value of the wrong shape, so a client sending
# `"content": ["a", "b"]` used to get a 201 for text that was never saved. JSON callers
# get a 422 naming the field instead. Forms can't produce these shapes.
module MemoryPayload
  extend ActiveSupport::Concern

  TEXT_FIELDS = %w[title content source category].freeze

  private

  def reject_misshaped_fields(key)
    return unless request.format.json?

    fields = params[key]
    return unless fields.is_a?(ActionController::Parameters)

    details = TEXT_FIELDS.each_with_object({}) do |field, errors|
      errors[field] = ["must be a string"] unless fields[field].nil? || fields[field].is_a?(String)
    end
    details["tags"] = ["must be an array of strings"] unless valid_tags?(fields[:tags])

    render_field_errors(details) if details.any?
  end

  # A blank string passes: it is how a form-encoded client says "no tags".
  def valid_tags?(tags)
    tags.nil? || (tags.is_a?(Array) && tags.all?(String))
  end
end
