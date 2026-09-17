# The workspace is part of the key because archiving or deleting one does not
# touch its memories, so a record-keyed fragment would keep reporting the old
# workspace.state long after the state changed.
json.cache! [memory, memory.workspace, "links_count:#{memory.links_count}"] do
  json.call(memory, :id, :title, :tags, :source, :category, :version)
  json.version_label memory.version_label
  json.has_versions memory.versioned?
  # Status stated outright, so a client can gate context injection without
  # parsing tags or comparing version numbers. root_id is the pointer that
  # makes current: false actionable.
  json.obsolete memory.obsolete?
  json.current memory.current_version?
  json.root_id memory.root_memory.id
  json.links_count memory.links_count
  json.created_at memory.created_at.utc
  json.updated_at memory.updated_at.utc
  json.url workspace_memory_url(memory.workspace, memory)

  json.workspace do
    json.id memory.workspace.id
    json.name memory.workspace.name
    json.state memory.workspace.status
    json.url workspace_url(memory.workspace)
  end
end

# Deliberately OUTSIDE the json.cache! block above. That cache is keyed on the
# memory alone, so a user-scoped field written inside it would be filled by
# whoever warmed the cache first and then served to every other user in the
# account.
#
# Opt-out because the export renders this partial once per historical version:
# a version is not individually pinnable, so every one of them would report the
# root's pinned: true. Pin state is per-user UI state and has no place in a
# portable data dump.
if defined?(include_pin_state) ? include_pin_state : true
  json.pinned pinned_for?(memory)
  json.pinned_at pinned_at_for(memory)
  json.pin_origin pin_origin_for_record(memory)
end
