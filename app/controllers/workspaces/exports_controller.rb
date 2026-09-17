module Workspaces
  class ExportsController < ApplicationController
    include WorkspaceScoped

    allow_token_authentication

    before_action :set_workspace

    def show
      @exported_at = Time.current.utc.iso8601
      response.headers["Content-Disposition"] = "inline"
      expires_now

      rows = Memory.where(workspace_id: @workspace.id).preload(
        :workspace,
        :child_versions,
        :incoming_links,
        :outgoing_links,
        content: :markdown_body
      ).to_a

      link_parents_to_loaded_roots(rows)
      @versions_by_root_id = rows.group_by { |memory| memory.parent_memory_id || memory.id }
      @root_memories = rows.select(&:root_version?).sort_by(&:id)

      respond_to do |format|
        format.json
      end
    end

    private

    # Every version of every memory in the workspace is already in `rows`, so a
    # parent_memory preload would re-load the roots as separate instances — ones
    # whose child_versions are not loaded, which is an extra query per root the
    # moment a version payload reports `current`. Point each child at the root
    # object we already have instead.
    def link_parents_to_loaded_roots(rows)
      by_id = rows.index_by(&:id)

      rows.each do |memory|
        next if memory.parent_memory_id.blank?

        memory.association(:parent_memory).target = by_id[memory.parent_memory_id]
      end
    end
  end
end
