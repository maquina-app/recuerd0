module ApplicationHelper
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

  BRAND_TITLE = "recuerd0"
  BRAND_TAGLINE = "recuerd0 — the knowledge base your AI tools deserve"
  THEMES = %w[light dark system].freeze
  THEME_COOKIE = "recuerd0_theme"

  # Tabs are how this audience navigates. Name the page, then the product, so a
  # row of recuerd0 tabs is still tellable apart.
  def page_title
    page = content_for(:title).presence || content_for(:page_title).presence
    page.present? ? "#{page} — #{BRAND_TITLE}" : BRAND_TAGLINE
  end

  # "system" (the default) resolves in the browser, where the media query lives;
  # an explicit choice is server-rendered so the first paint is already right.
  def theme_preference
    theme = cookies[THEME_COOKIE]
    THEMES.include?(theme) ? theme : "system"
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
