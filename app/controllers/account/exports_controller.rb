class Account::ExportsController < ApplicationController
  include AdminAuthorizable

  before_action :require_admin

  def create
    account = Current.account
    exports_this_month = account.account_exports.exports_this_month.count

    if exports_this_month >= AccountExport::MONTHLY_LIMIT
      redirect_to account_path, alert: t(".limit_reached")
      return
    end

    export = account.account_exports.create!(user: Current.user, status: "pending")
    Accounts::ExportJob.perform_later(export.id)
    AccountExportMailer.started(export).deliver_later

    redirect_to account_path, notice: t(".started")
  end

  def show
    export = Current.account.account_exports.find(params[:id])

    unless export.downloadable?
      redirect_to account_path, alert: t(".expired")
      return
    end

    # Stream directly from our authenticated controller instead of
    # redirecting to Active Storage's publicly accessible URL.
    send_data export.archive.download,
      filename: export.archive.filename.to_s,
      content_type: export.archive.content_type,
      disposition: "attachment"
  end
end
