class PinsController < ApplicationController
  PINNABLE_TYPES = %w[Workspace Memory].freeze

  before_action :set_pinnable
  before_action :check_pin_limit, only: :create

  def create
    @pin = @pinnable.pin!(Current.user)

    redirect_back(fallback_location: workspaces_path, notice: t(".created"))
  rescue ActiveRecord::RecordInvalid => e
    redirect_back(fallback_location: workspaces_path, alert: e.message)
  end

  def destroy
    @unpinned = @pinnable.unpin!(Current.user)

    redirect_back(fallback_location: workspaces_path, notice: t(".destroyed"))
  end

  private

  def set_pinnable
    @pinnable = find_pinnable
  rescue ActiveRecord::RecordNotFound
    redirect_back(fallback_location: workspaces_path, alert: t("pins.not_found"))
  end

  def find_pinnable
    type = params[:pinnable_type]
    raise ActiveRecord::RecordNotFound unless PINNABLE_TYPES.include?(type)

    Current.user.send(type.tableize).with_deleted.find(params[:pinnable_id])
  end

  def check_pin_limit
    unless Current.user.can_pin_more?(10)
      respond_to do |format|
        format.turbo_stream {
          flash.now[:alert] = t("pins.limit_reached", limit: 10)
          render turbo_stream: turbo_stream.refresh
        }
        format.html { redirect_back(fallback_location: workspaces_path, alert: t("pins.limit_reached", limit: 10)) }
      end
    end
  end
end
