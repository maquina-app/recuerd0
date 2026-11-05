class MemoriesController < ApplicationController
  include WorkspaceScoped
  include MemoryFilterable
  include ObsoleteFilterable
  include ContentRenderable
  include OwnershipAuthorizable
  include MemoryPage

  allow_token_authentication

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_memory, only: %i[show edit update destroy]
  before_action -> { require_manage_access(@memory) }, only: :destroy
  before_action :require_active_workspace, only: %i[new create edit update destroy]

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
        return unless validate_category_param!

        scope = apply_obsolete_filter(scope)
        scope = apply_memory_filters(scope)
        @pagy, @memories = pagy(scope, limit: permitted_per_page)
        @memories = @memories.map { |m| m.versioned? ? m.current_version : m }
        set_pagination_headers(@pagy)
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        return redirect_to_version_url if @memory.parent_memory_id

        prepare_memory_page(@memory.current_version)
        load_link_candidates
        track_event("memory.view", resource: @memory)
      end
      format.json do
        track_event("memory.view", resource: @memory)
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
    @memory = Memory.create_with_content(@workspace, memory_params.to_h.merge(created_by: Current.user))

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

  # There is one thing to edit: the current version. An old version's edit URL
  # used to open that version's text and then silently save over the current one.
  def edit
    return redirect_to edit_workspace_memory_path(@workspace, @memory.stable_id) if @memory.parent_memory_id

    @memory = @memory.current_version
    @memory.content || @memory.build_content(body: "")
  end

  def update
    @memory = @memory.resolve_current_version

    if !@memory.current_version?
      @memory.errors.add(:base, :historical_version_immutable)
    elsif save_as_new_version?
      return if save_new_version
    else
      @memory.update_with_content(memory_params)
    end

    if @memory.errors.empty?
      @memory.root_memory.touch
      track_event("memory.update", resource: @memory)
      respond_to do |format|
        format.html { redirect_to workspace_memory_path(@workspace, @memory.stable_id), notice: t(".updated"), status: :see_other }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :edit, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@memory) }
      end
    end
  end

  def destroy
    track_event("memory.destroy", resource: @memory)
    # The dialog promises every version goes. Destroying the row in the URL only
    # removed that one version when the page was showing a later one.
    @memory.root_memory.destroy

    respond_to do |format|
      format.html { redirect_to workspace_path(@workspace), notice: t(".destroyed"), status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  # Only the editor's primary button asks for this. A plain PATCH, which is what
  # the REST API sends, keeps meaning "update in place".
  def save_as_new_version?
    params[:save_as] == "new_version"
  end

  # true when it answered the request itself.
  def save_new_version
    version = @memory.save_as_new_version(memory_params.to_h.symbolize_keys.merge(created_by: Current.user))
    return false unless version

    track_event("version.create", resource: version)
    redirect_to workspace_memory_path(@workspace, @memory.stable_id),
      notice: t(".version_created", version: version.version_label), status: :see_other
    true
  end

  # /memories/<root> always opens the current version, and an older one has its
  # own explicit URL. Links saved before that, which point at a version's row,
  # land on whichever of the two that version is now.
  def redirect_to_version_url
    if @memory.current_version?
      redirect_to workspace_memory_path(@workspace, @memory.stable_id, request.query_parameters)
    else
      redirect_to workspace_memory_version_path(@workspace, @memory.stable_id, @memory)
    end
  end

  # Candidates for the "Link a memory" picker. Account-scoped (never just the
  # current workspace — links are explicitly allowed to cross them), with the
  # memory itself and anything already linked removed so the list only ever
  # offers a link that can actually be made.
  def load_link_candidates
    @link_picker_open = params.key?(:link_q)
    @link_query = params[:link_q].to_s.strip.first(80).presence
    return if @link_query.blank?

    excluded = [@root_memory.id] + @root_memory.linked_memory_ids

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
    params.require(:memory).permit(:title, :source, :content, :category, :change_note, tags: [])
  end
end
