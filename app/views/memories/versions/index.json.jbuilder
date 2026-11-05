# No pin state: a version is not individually pinnable, so each one would only repeat
# its root's. Same reasoning as the export.
json.array! @all_versions, partial: "memories/memory", as: :memory, include_pin_state: false
