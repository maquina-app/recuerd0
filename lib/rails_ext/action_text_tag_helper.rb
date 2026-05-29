# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
module ActionText
  module TagHelper
    def markdown_area(record, name, value: nil, **options)
      field_name = "#{record.class.model_name.param_key}[#{name}]"
      value = record.safe_markdown_attribute(name).content.to_s if value.nil?

      data = options.delete(:data) || {}
      if record.persisted?
        data.reverse_merge! \
          uploads_url: action_text_markdown_uploads_url(record_gid: record.to_signed_global_id.to_s, attribute_name: name, format: "json")
      end

      tag.house_md value, name: field_name, data: data, **options
    end

    def house_toolbar(**, &)
      tag.house_md_toolbar(**, &)
    end

    def house_toolbar_button(action, **options, &)
      title = options.delete(:title) || I18n.t("shared.house_toolbar.#{action}", default: action.to_s.humanize)
      tag.button(title: title, data: {"house-md-action": action}, **options, &)
    end

    def house_toolbar_file_upload_button(name: "upload", title: nil, **, &)
      title ||= I18n.t("shared.house_toolbar.#{name}", default: name.to_s.humanize)
      tag.label(title: title, **) do
        safe_join [
          file_field_tag(name, data: {"house-md-toolbar-file-picker": true}, style: "display: none;"),
          capture(&)
        ]
      end
    end
  end
end

module ActionView::Helpers
  class FormBuilder
    def markdown_area(method, **)
      @template.markdown_area(@object, method, **)
    end
  end
end
