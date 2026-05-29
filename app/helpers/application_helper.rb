module ApplicationHelper
  include Pagy::Frontend
  include MaquinaComponentsHelper

  # Avatar helper methods
  def avatar_classes(size: "h-10 w-10", grayscale: false, css_classes: "")
    class_names(
      "relative flex shrink-0 overflow-hidden rounded-full",
      size,
      "grayscale" => grayscale,
      css_classes => css_classes.present?
    )
  end

  def avatar_fallback(alt, fallback = nil)
    if fallback.present?
      fallback
    elsif alt.present?
      # Get initials from alt text (first letter of first two words)
      alt.split.take(2).map(&:first).join.upcase
    else
      "?"
    end
  end
end
