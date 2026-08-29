class Memories::LinksController < ApplicationController
  before_action :set_workspace
  before_action :set_memory
  before_action :require_full_access, only: %i[create destroy], if: :api_request?

  # GET /workspaces/:workspace_id/memories/:memory_id/links.json
  def index
    @links = @memory.linked_memories
      .latest_versions
      .order(updated_at: :desc)
    last_modified = [@memory.updated_at, @links.maximum(:updated_at)].compact.max
    stale?(etag: [@memory, @links.to_a], last_modified: last_modified)
  end

  # POST /workspaces/:workspace_id/memories/:memory_id/links.json
  def create
    other_id = params[:to_memory_id] || params.dig(:link, :to_memory_id)
    if other_id.blank?
      return render_validation_error("to_memory_id is required")
    end

    if other_id.to_i == @memory.id
      link = MemoryLink.new(from_memory: @memory, to_memory: @memory)
      link.valid?
      return render_validation_errors(link)
    end

    other = find_other_memory(other_id)
    unless other
      return render_validation_error("to_memory_id must reference a memory in your account")
    end

    @link = MemoryLink.new(from_memory: @memory, to_memory: other)
    if @link.save
      @other = @link.other_side(@memory)
      render :show, status: :created
    else
      render_validation_errors(@link)
    end
  end

  # DELETE /workspaces/:workspace_id/memories/:memory_id/links/:id.json
  def destroy
    other_id = params[:id].to_i
    other = find_other_memory(other_id)
    return render_not_found unless other

    link = link_between(@memory.id, other_id)
    return render_not_found unless link

    link.destroy
    head :no_content
  end

  # POST /workspaces/:workspace_id/memories/:memory_id/linking
  # Browser counterpart to #create. Redirects back to the memory so the page
  # morphs (same pathname + replace action) instead of returning JSON.
  def create_html
    other = find_other_memory(params[:to_memory_id])

    if other.nil?
      return redirect_back_to_memory(alert: t("memories.links.not_found"))
    end

    link = MemoryLink.new(from_memory: @memory, to_memory: other)
    if link.save
      redirect_back_to_memory(notice: t("memories.links.created", title: other.display_title))
    else
      redirect_back_to_memory(alert: link.errors.full_messages.to_sentence)
    end
  end

  # DELETE /workspaces/:workspace_id/memories/:memory_id/linking/:other_id
  # :other_id is the OTHER memory's id, matching the JSON endpoint's contract.
  def destroy_html
    other = find_other_memory(params[:other_id])
    link = other && link_between(@memory.id, other.id)

    if link.nil?
      return redirect_back_to_memory(alert: t("memories.links.not_found"))
    end

    link.destroy
    redirect_back_to_memory(notice: t("memories.links.removed", title: other.display_title))
  end

  private

  # Turbo keeps the original method through a 302 for every verb except POST,
  # so a DELETE that redirects must answer 303 or the browser re-issues the
  # DELETE against the redirect target.
  def redirect_back_to_memory(flash_options)
    redirect_to workspace_memory_path(@workspace, @memory), **flash_options, status: :see_other
  end

  def link_between(a, b)
    MemoryLink.where(
      "(from_memory_id = ? AND to_memory_id = ?) OR (from_memory_id = ? AND to_memory_id = ?)",
      a, b, b, a
    ).first
  end

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id])
  end

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
  end

  def find_other_memory(id)
    Memory.joins(:workspace)
      .where(workspaces: {account_id: Current.account.id})
      .find_by(id: id)
  end
end
