# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
module ActionText
  module HasMarkdown
    extend ActiveSupport::Concern

    class_methods do
      def has_markdown(name, strict_loading: strict_loading_by_default)
        association = :"markdown_#{name}"

        define_method(name) { public_send(association) || public_send(:"build_#{association}") }
        define_method(:"#{name}?") { public_send(association).present? }
        define_method(:"#{name}=") { |content| public_send(name).content = content }

        has_one association, -> { where(name: name) },
          class_name: "ActionText::Markdown", as: :record, inverse_of: :record, autosave: true, dependent: :destroy,
          strict_loading: strict_loading

        scope :"with_markdown_#{name}", -> { includes("markdown_#{name}") }
        scope :"with_markdown_#{name}_and_embeds", -> { includes("markdown_#{name}": {embeds_attachments: :blob}) }
      end
    end

    def safe_markdown_attribute(name)
      if self.class.reflect_on_association("markdown_#{name}")&.klass == ActionText::Markdown
        public_send(name)
      end
    end

    # Authorization predicate for markdown uploads — controllers ask the record,
    # not the other way around. Default rule: the actor must share the record's
    # account. Override on the including model to tighten or loosen.
    def markdown_uploadable_by?(user)
      return false if user.nil?
      return false unless respond_to?(:account)

      account == user.account
    end
  end
end

ActiveSupport.on_load :active_record do
  include ActionText::HasMarkdown
end
