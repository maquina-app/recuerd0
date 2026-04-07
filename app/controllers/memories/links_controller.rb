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

    link = MemoryLink.where(
      "(from_memory_id = ? AND to_memory_id = ?) OR (from_memory_id = ? AND to_memory_id = ?)",
      @memory.id, other_id, other_id, @memory.id
    ).first
    return render_not_found unless link

    link.destroy
    head :no_content
  end

  private

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
