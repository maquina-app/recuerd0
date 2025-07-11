module ApplicationHelper
  include Pagy::Frontend

  # Utility method similar to clsx/cn in shadcn/ui
  def cn(*classes)
    classes.flatten.compact.join(" ")
  end
end
