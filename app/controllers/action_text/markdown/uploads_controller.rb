# Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
# https://github.com/basecamp/writebook
class ActionText::Markdown::UploadsController < ApplicationController
  allow_unauthenticated_access only: :show

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
    expires_in 1.year, public: true
    redirect_to @attachment.url, allow_other_host: true
  end
end
