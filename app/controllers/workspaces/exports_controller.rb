module Workspaces
  class ExportsController < ApplicationController
    include WorkspaceScoped

    before_action :set_workspace

    def show
      @exported_at = Time.current.utc.iso8601
      response.headers["Content-Disposition"] = "inline"
      expires_now

      rows = Memory.where(workspace_id: @workspace.id).preload(
        :workspace,
        :parent_memory,
        :child_versions,
        :incoming_links,
        :outgoing_links,
        content: :markdown_body
      ).to_a

      @versions_by_root_id = rows.group_by { |memory| memory.parent_memory_id || memory.id }
      @root_memories = rows.select(&:root_version?).sort_by(&:id)

      respond_to do |format|
        format.json
      end
    end
  end
end
