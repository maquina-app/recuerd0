class PinsController < ApplicationController
  PINNABLE_TYPES = %w[Workspace Memory].freeze

  before_action :set_pinnable
  before_action :check_pin_limit, only: :create

  def create
    @pin = @pinnable.pin!(Current.user)
    track_event("pin.create", resource: @pinnable)

    redirect_back(fallback_location: workspaces_path, notice: t(".created"), status: :see_other)
  rescue ActiveRecord::RecordInvalid => e
    redirect_back(fallback_location: workspaces_path, alert: e.message, status: :see_other)
  end

  def destroy
    @unpinned = @pinnable.unpin!(Current.user)
    track_event("pin.destroy", resource: @pinnable)

    redirect_back(fallback_location: workspaces_path, notice: t(".destroyed"), status: :see_other)
  end

  private

  def set_pinnable
    @pinnable = find_pinnable
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: workspaces_path, alert: t("pins.not_found"), status: :see_other)
  end

  def find_pinnable
    type = params[:pinnable_type]
    raise ActiveRecord::RecordNotFound unless PINNABLE_TYPES.include?(type)

    case type
    when "Workspace"
      Current.account.workspaces.find(params[:pinnable_id])
    when "Memory"
      Memory.joins(:workspace).where(workspaces: {account_id: Current.account.id}).find(params[:pinnable_id])
    end
  end

  def check_pin_limit
    unless Current.user.can_pin_more?
      alert = t("pins.limit_reached", limit: User::PIN_LIMIT)
      respond_to do |format|
        format.turbo_stream {
          flash.now[:alert] = alert
          render turbo_stream: turbo_stream.refresh
        }
        format.html { redirect_back(fallback_location: workspaces_path, alert: alert, status: :see_other) }
      end
    end
  end
end
