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

    def to_html
      (renderer.try(:call) || renderer).render(content).html_safe
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
