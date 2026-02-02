module ApplicationHelper
  include Pagy::Frontend
  include MaquinaComponentsHelper

  # Merges CSS classes using Tailwind's convention
  # Similar to clsx or cn() in JavaScript
  def cn(*classes)
    classes.compact.flatten.select(&:present?).join(" ")
  end

  # Helper method to generate breadcrumbs
  # Usage: breadcrumbs({ "Home" => root_path, "Workspaces" => workspaces_path }, "Current Page")
  def breadcrumbs(links = {}, current_page = nil)
    render "components/breadcrumbs" do
      render "components/breadcrumbs/list" do
        items = []

        # Add all links
        links.each_with_index do |(text, path), index|
          items << capture do
            render "components/breadcrumbs/item" do
              render "components/breadcrumbs/link", href: path do
                text
              end
            end
          end

          # Add separator after each link except the last one (if there's no current page)
          if index < links.size - 1 || current_page.present?
            items << capture do
              render "components/breadcrumbs/separator"
            end
          end
        end

        # Add current page if provided
        if current_page.present?
          items << capture do
            render "components/breadcrumbs/item" do
              render "components/breadcrumbs/page" do
                current_page
              end
            end
          end
        end

        safe_join(items)
      end
    end
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
