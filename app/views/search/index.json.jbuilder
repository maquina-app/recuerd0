json.query @query
json.total_results @pagy.count

json.results @memories do |memory|
  json.partial! "memories/memory", memory: memory
  json.snippet memory_snippet(memory)
end
