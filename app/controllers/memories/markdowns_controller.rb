class Memories::MarkdownsController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :set_memory

  def show
    @memory = @memory.resolve_current_version

    send_data @memory.content&.body || "",
      type: "text/markdown; charset=utf-8",
      disposition: "inline",
      filename: "#{@memory.display_title.parameterize}.md"
  end

  private

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
  end
end
