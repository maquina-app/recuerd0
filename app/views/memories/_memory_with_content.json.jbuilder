json.partial! "memories/memory", memory: memory

json.content do
  json.body memory.content&.body
end
