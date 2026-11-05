# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
module ActionText
  class Markdown < Record
    DEFAULT_RENDERER_OPTIONS = {
      filter_html: false
    }

    DEFAULT_MARKDOWN_EXTENSIONS = {
      autolink: true,
      highlight: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      lax_spacing: true,
      strikethrough: true,
      tables: true
    }

    mattr_accessor :renderer, default: Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(DEFAULT_RENDERER_OPTIONS), DEFAULT_MARKDOWN_EXTENSIONS
    )

    belongs_to :record, polymorphic: true, touch: true

    # Redcarpet will not let a fence interrupt a list item: without a blank line
    # the fence turns into inline code inside the last bullet, while the editor
    # and any CommonMark reader see a code block. Only unindented fences move; an
    # indented one is deliberately part of its list item. Idempotent, and applied
    # on save as well as here so memories saved before the fix render correctly.
    LIST_ITEM = /\A\s*(?:[-*+]|\d+[.)])\s/
    FENCE = /\A(?:```|~~~)/

    def self.separate_fences_from_lists(markdown)
      in_fence = false
      in_list = false

      markdown.to_s.each_line.with_object(+"") do |line, output|
        if in_fence
          in_fence = false if line.match?(FENCE)
        elsif line.match?(FENCE)
          output << "\n" if in_list
          in_fence = true
          in_list = false
        elsif line.strip.empty?
          in_list = false
        elsif line.match?(LIST_ITEM)
          in_list = true
        end

        output << line
      end
    end

    def to_html
      (renderer.try(:call) || renderer).render(self.class.separate_fences_from_lists(content)).html_safe
    end
  end
end

module ActionText::Markdown::Uploads
  extend ActiveSupport::Concern

  MAX_UPLOAD_BYTES = 10.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze

  included do
    has_many_attached :uploads, dependent: :destroy

    validate :uploads_within_limits
  end

  private

  def uploads_within_limits
    uploads.each do |upload|
      next unless upload.new_record?

      if upload.byte_size > MAX_UPLOAD_BYTES
        errors.add(:uploads, :too_large)
      elsif ALLOWED_CONTENT_TYPES.exclude?(upload.content_type)
        errors.add(:uploads, :wrong_format)
      end
    end
  end
end

ActiveSupport.on_load :active_storage_attachment do
  ActionText::Markdown.include(ActionText::Markdown::Uploads)
end

ActiveSupport.run_load_hooks :action_text_markdown, ActionText::Markdown
