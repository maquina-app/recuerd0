# Pagination navigation, rendered from the engine's components/pagination/*
# partials.
#
# maquina-components ships its own `pagination_nav`, but it reads Pagy internals
# that Pagy 43 removed — `pagy.vars`, `Pagy::DEFAULT[:page_param]` — and the gem
# declares no Pagy dependency, so nothing warns: it resolves fine and raises at
# render time. The partials it renders are plain markup and are unaffected, so
# the app keeps them and owns only the Pagy-facing part. Named differently from
# the gem helper on purpose, rather than shadowing it, so the next gem bump
# cannot silently take this over again.
module PaginationHelper
  # @param pagy [Pagy] the paginator
  # @param route_helper [Symbol] route helper name, e.g. :workspaces_path
  # @param params [Hash] params to carry through to every page link
  # @param turbo [Hash] Turbo behaviour for the links
  def paginate_nav(pagy, route_helper, params: {}, turbo: {action: :replace}, show_labels: true, css_classes: "", **html_options)
    return if pagy.last <= 1

    link = page_link_options(pagy, route_helper, params, turbo)

    render "components/pagination", css_classes: css_classes, **html_options do
      render "components/pagination/content" do
        safe_join([
          pagination_step(pagy, :previous, link, show_labels),
          pagination_pages(pagy, link),
          pagination_step(pagy, :next, link, show_labels)
        ])
      end
    end
  end

  private

  # One closure carries the routing and Turbo context, so the parts below take
  # a page number and nothing else.
  def page_link_options(pagy, route_helper, extra_params, turbo)
    page_key = pagy.options[:page_key] || Pagy::DEFAULT[:page_key]
    query = request.query_parameters.except(page_key.to_s).merge(extra_params)
    data = turbo.blank? ? {} : {turbo_action: turbo[:action], turbo_frame: turbo[:frame]}.compact

    ->(page) { {href: send(route_helper, query.merge(page_key => page)), data: data} }
  end

  def pagination_step(pagy, direction, link, show_label)
    page = pagy.public_send(direction)

    render "components/pagination/item" do
      if page
        render "components/pagination/#{direction}", show_label: show_label, **link.call(page)
      else
        render "components/pagination/#{direction}", show_label: show_label, disabled: true
      end
    end
  end

  def pagination_pages(pagy, link)
    # #series is protected in Pagy 43: it is meant to be called from inside the
    # paginator by Pagy's own series_nav, which renders Pagy's markup rather
    # than the engine's. Reaching it is the price of keeping these components.
    pagy.send(:series).map do |item|
      render "components/pagination/item" do
        if item == :gap
          render "components/pagination/ellipsis"
        else
          # The current page arrives as a String, every other page as an Integer.
          render "components/pagination/link", active: item.is_a?(String), **link.call(item.to_i) do
            item.to_s
          end
        end
      end
    end
  end
end
