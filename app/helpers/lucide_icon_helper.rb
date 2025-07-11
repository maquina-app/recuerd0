# app/helpers/lucide_icon_helper.rb
module LucideIconHelper
  # Renders a Lucide icon as inline SVG
  # @param name [String, Symbol] The icon name (e.g., :plus, "chevron-right")
  # @param options [Hash] HTML options for the SVG element
  # @option options [String] :size The size of the icon (default: "w-4 h-4")
  # @option options [String] :stroke_width The stroke width (default: "2")
  # @option options [String] :class Additional CSS classes
  def lucide_icon(name, options = {})
    icon_name = name.to_s.downcase.tr("_", "-")
    size = options.delete(:size) || "w-4 h-4"
    stroke_width = options.delete(:stroke_width) || "2"
    css_class = ["lucide", "lucide-#{icon_name}", size, options[:class]].compact.join(" ")

    svg_attrs = {
      xmlns: "http://www.w3.org/2000/svg",
      width: "24",
      height: "24",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": stroke_width,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      class: css_class
    }.merge(options.except(:class))

    content_tag(:svg, svg_attrs) do
      icon_path(icon_name).html_safe
    end
  end

  private

  # Returns the path data for common Lucide icons
  # Add more icons as needed
  def icon_path(name)
    icons = {
      "plus" => '<path d="M5 12h14"/><path d="M12 5v14"/>',
      "edit" => '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>',
      "trash" => '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>',
      "trash-2" => '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>',
      "chevron-right" => '<path d="m9 18 6-6-6-6"/>',
      "chevron-left" => '<path d="m15 18-6-6 6-6"/>',
      "arrow-left" => '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
      "arrow-right" => '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
      "folder-plus" => '<path d="M12 10v6"/><path d="M9 13h6"/><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
      "brain" => '<path d="M12 5a3 3 0 1 0-5.997.125 4 4 0 0 0-2.526 5.77 4 4 0 0 0 .556 6.588A4 4 0 1 0 12 18Z"/><path d="M9 13h6"/><path d="M12 5a3 3 0 1 1 5.997.125 4 4 0 0 1 2.526 5.77 4 4 0 0 1-.556 6.588A4 4 0 1 1 12 18Z"/>',
      "bookmark" => '<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/>',
      "bookmark-plus" => '<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/><line x1="12" x2="12" y1="7" y2="13"/><line x1="9" x2="15" y1="10" y2="10"/>',
      "settings" => '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
      "eye" => '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
      "clock" => '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
      "tag" => '<path d="M12.586 2.586A2 2 0 0 0 11.172 2H3a1 1 0 0 0-1 1v8.172a2 2 0 0 0 .586 1.414l7 7a2 2 0 0 0 2.828 0l4.414-4.414a2 2 0 0 0 0-2.828l-7-7z"/><circle cx="7.5" cy="7.5" r="0.5" fill="currentColor"/>',
      "tags" => '<path d="m15 5 6.3 6.3a2.4 2.4 0 0 1 0 3.4L17 19"/><path d="M9.586 5.586A2 2 0 0 0 8.172 5H3a1 1 0 0 0-1 1v5.172a2 2 0 0 0 .586 1.414L8.29 18.29a2.426 2.426 0 0 0 3.42 0l3.58-3.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="6.5" cy="9.5" r=".5" fill="currentColor"/>',
      "x" => '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
      "check" => '<path d="M20 6 9 17l-5-5"/>',
      "more-horizontal" => '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
      "pen-square" => '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/>'
    }

    icons[name] || '<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>'
  end
end
