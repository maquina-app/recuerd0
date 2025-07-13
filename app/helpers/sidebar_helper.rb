module SidebarHelper
  def sidebar_link_class(path)
    current_page?(path) ? "true" : "false"
  end
end
