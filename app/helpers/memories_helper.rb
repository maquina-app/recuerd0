module MemoriesHelper
  # "v7–v9", or "v9" for a single version.
  def version_range_label(versions)
    [versions.first, versions.last].uniq.map(&:version_label).join("–")
  end

  # The address a person should keep: it always opens the current version.
  def stable_memory_path(workspace, memory)
    workspace_memory_path(workspace, memory.stable_id)
  end

  # `current` is passed by a caller holding the whole history, to spare a query
  # per version.
  def version_page_path(workspace, version, current: version.current_version?)
    return stable_memory_path(workspace, version) if current

    workspace_memory_version_path(workspace, version.stable_id, version)
  end

  # When this version's text last changed. A root row's updated_at moves whenever
  # a later version is saved, so once it has children its creation is the honest
  # answer.
  def version_saved_at(memory)
    (memory.root_version? && memory.versioned?) ? memory.created_at : memory.updated_at
  end

  def creator_name(record)
    person_name(record.ownership_record.created_by)
  end

  # nil means no recorded creator, which belongs to the account admin.
  def person_name(user)
    return t("ownership.you") if user == Current.user || (user.nil? && Current.user.admin?)

    user&.display_name || account_admin_name
  end

  # "system" is a storage value, not something to show a person. Only http(s)
  # sources become links: this is free text an agent or API client can set.
  def memory_source_value(source)
    return t("memories.memory.source_system") if source == "system"
    return source unless source.match?(%r{\Ahttps?://\S+\z}i)

    link_to source, source, target: "_blank", rel: "noopener noreferrer", class: "src-link"
  end

  private

  def account_admin_name
    @account_admin_name ||= Current.account.users.where(role: "admin").order(:created_at).first&.display_name ||
      t("ownership.account_admin")
  end
end
