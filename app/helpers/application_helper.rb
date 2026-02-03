module ApplicationHelper
  include Pagy::Frontend
  include MaquinaComponentsHelper

  # Merges CSS classes using Tailwind's convention
  # Similar to clsx or cn() in JavaScript
  def cn(*classes)
    classes.compact.flatten.select(&:present?).join(" ")
  end

  # Avatar helper methods
  def avatar_classes(size: "h-10 w-10", grayscale: false, class_names: "")
    base_classes = "relative flex shrink-0 overflow-hidden rounded-full"
    grayscale_classes = grayscale ? "grayscale" : ""

    cn(base_classes, size, grayscale_classes, class_names)
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
