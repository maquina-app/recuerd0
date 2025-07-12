module SidebarHelper
  def sidebar_link_class(path)
    current_page?(path) ? "true" : "false"
  end

  def sidebar_cookie_name
    "recuerd0_sidebar_state"
  end

  def sidebar_cookie_max_age
    60 * 60 * 24 * 365 # 1 year
  end

  def sidebar_keyboard_shortcut
    "b" # cmd+b or ctrl+b
  end
end
