class Memories::MarkdownsController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :set_memory

  def show
    send_data @memory.content&.body&.content.to_s,
      type: "text/markdown; charset=utf-8",
      disposition: "inline",
      filename: "#{@memory.display_title.parameterize}.md"
  end

  private

  # A version's URL returns that version; the memory's own URL returns the
  # current one, the same as opening it.
  def set_memory
    memory = @workspace.memories.find(params[:memory_id])

    @memory = if params[:version_id]
      memory.all_versions.find(params[:version_id])
    else
      memory.resolve_current_version
    end
  end
end
