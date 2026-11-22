# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
#
# Writebook serves uploads to anyone holding the slug. Memories are private to an
# account, so here a read passes the same check as a write, and the redirect is
# never cached by a shared proxy.
class ActionText::Markdown::UploadsController < ApplicationController
  before_action do
    ActiveStorage::Current.url_options = {protocol: request.protocol, host: request.host, port: request.port}
  end

  def create
    @record = GlobalID::Locator.locate_signed(params[:record_gid])
    head :forbidden and return unless @record.markdown_uploadable_by?(Current.user)

    @markdown = @record.safe_markdown_attribute(params[:attribute_name])
    head :not_found and return if @markdown.nil?

    @markdown.uploads.attach([params[:file]])

    if @markdown.save
      @upload = @markdown.uploads.attachments.last
      render :create, status: :created, formats: :json
    else
      render json: {errors: @markdown.errors.full_messages}, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  end

  def show
    @attachment = ActiveStorage::Attachment.find_by!(slug: "#{params[:slug]}.#{params[:format]}")
    raise ActiveRecord::RecordNotFound unless @attachment.record.record.markdown_uploadable_by?(Current.user)

    expires_in 5.minutes, private: true
    redirect_to @attachment.url, allow_other_host: true
  end
end
