class MemoriesController < ApplicationController
  include WorkspaceScoped
  include MemoryFilterable
  include ObsoleteFilterable
  include ContentRenderable

  before_action :set_workspace
  before_action :set_memory, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[new create edit update destroy]
  before_action :require_full_access, only: %i[create update destroy], if: :api_request?

  def index
    scope = @workspace.memories
      .latest_versions
      .includes(:content, child_versions: :content)
      .order(updated_at: :desc)

    respond_to do |format|
      format.html do
        @pagy, @memories = pagy(scope, items: 25)
        redirect_to workspace_path(@workspace)
      end
      format.json do
        scope = apply_obsolete_filter(scope)
        scope = apply_memory_filters(scope)
        @pagy, @memories = pagy(scope, limit: permitted_per_page)
        @memories = @memories.map { |m| m.versioned? ? m.current_version : m }
        set_pagination_headers(@pagy)
      end
    end
  end

  def show
    @all_versions = @memory.all_versions
    @viewing_old_version = @memory.versioned? && !@memory.current_version?
    load_link_candidates
    track_event("memory.view", resource: @memory)

    respond_to do |format|
      format.html
      format.json do
        @memory = @memory.resolve_current_version
        return validate_content_params if content_filtered?
        # The viewer is part of the validator because pinned/pinned_at are
        # rendered per user, outside the record-keyed json.cache! block.
        return unless stale?(etag: [@memory, Current.user])
      end
    end
  end

  def new
    prefill = prefill_params
    @memory = @workspace.memories.build(prefill.slice(:title, :category, :tags))
    @memory.build_content(body: prefill[:content]) if prefill[:content]
  end

  def create
    @memory = Memory.create_with_content(@workspace, memory_params)

    if @memory.persisted?
      track_event("memory.create", resource: @memory)
      respond_to do |format|
        format.html { redirect_to [@workspace, @memory], notice: t(".created") }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :new, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@memory) }
      end
    end
  end

  def edit
    @memory.content || @memory.build_content(body: "")
  end

  def update
    @memory = @memory.resolve_current_version

    if @memory.current_version?
      @memory.update_with_content(memory_params)
    else
      @memory.errors.add(:base, :historical_version_immutable)
    end

    if @memory.errors.empty?
      @memory.root_memory.touch
      track_event("memory.update", resource: @memory)
      respond_to do |format|
        # An autosave is a background write, not a navigation: redirecting would
        # make the editor fetch and discard a full show page every few seconds.
        format.html { autosave? ? head(:no_content) : redirect_to([@workspace, @memory], notice: t(".updated")) }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html do
          # The editor keeps its own copy of the text, so a failed autosave only
          # needs a status code to flip the chip to "Not saved" — re-rendering
          # the form underneath it would clobber what the person is typing.
          if autosave?
            head :unprocessable_entity
          else
            flash.now[:alert] = t(".errors")
            render :edit, status: :unprocessable_entity
          end
        end
        format.json { render_validation_errors(@memory) }
      end
    end
  end

  def destroy
    track_event("memory.destroy", resource: @memory)
    @memory.destroy

    respond_to do |format|
      format.html { redirect_to workspace_path(@workspace), notice: t(".destroyed"), status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  # Candidates for the "Link a memory" picker. Account-scoped (never just the
  # current workspace — links are explicitly allowed to cross them), with the
  # memory itself and anything already linked removed so the list only ever
  # offers a link that can actually be made.
  def load_link_candidates
    @link_query = params[:link_q].to_s.strip.first(80).presence
    return if @link_query.blank?

    excluded = [@memory.id] + @memory.linked_memory_ids

    @link_candidates = Memory
      .joins(:workspace)
      .where(workspaces: {account_id: Current.account.id})
      .latest_versions
      .where.not(id: excluded)
      .search(@link_query)
      .includes(:workspace)
      .order(updated_at: :desc)
      .limit(8)
  end

  def autosave?
    params[:autosave].present?
  end

  def set_memory
    @memory = @workspace.memories.find(params[:id])
  end

  def content_filtered?
    grep_mode? || line_range_requested?
  end

  def validate_content_params
    if grep_mode?
      parse_grep_params
      render_validation_error(t("memories.show.grep_query_required")) if @grep_query.blank?
    elsif line_range_requested?
      parse_line_range_params
      render_validation_error(t("memories.show.invalid_line_range")) if invalid_line_range?
    end
  end

  # Param names are a contract with fragua's capture-candidate promote URL — change both or neither.
  def prefill_params
    prefill = params.permit(:title, :content, :category, tags: []).compact_blank
    prefill.delete(:category) unless Memory::CATEGORIES.include?(prefill[:category])
    prefill[:tags]&.select! { |tag| tag.is_a?(String) && tag.present? }
    prefill
  end

  def memory_params
    params.require(:memory).permit(:title, :source, :content, :category, tags: [])
  end
end
