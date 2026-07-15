# Read-only detector for likely-duplicate memories within a workspace. Clusters
# latest-version memories by a blend of tag overlap (Jaccard) and title
# similarity (trigram Jaccard — the same trigram basis the FTS index tokenizes
# with). It only *suggests* clusters; merging remains a human decision.
class WorkspaceMergeCandidates
  DEFAULT_MIN_SCORE = 0.5
  # Bound the O(n^2) pairwise scan. Workspaces beyond this are sampled by recency;
  # callers that need full coverage should narrow by workspace.
  MAX_MEMORIES = 500
  MAX_CLUSTERS = 50
  TITLE_WEIGHT = 0.6
  TAG_WEIGHT = 0.4

  Cluster = Struct.new(:score, :reasons, :memories, keyword_init: true)

  def initialize(workspace, min_score: DEFAULT_MIN_SCORE)
    @workspace = workspace
    @min_score = min_score.to_f.clamp(0.0, 1.0)
  end

  # => [Cluster(score:, reasons:, memories: [Memory, ...]), ...] sorted best-first.
  def clusters
    memories = load_memories
    return [] if memories.size < 2

    pairs = similar_pairs(memories)
    build_clusters(memories, pairs).sort_by { |c| -c.score }.first(MAX_CLUSTERS)
  end

  private

  def load_memories
    @workspace.memories.latest_versions
      .includes(:workspace)
      .order(created_at: :desc)
      .limit(MAX_MEMORIES)
      .to_a
  end

  # All memory pairs scoring at/above the threshold, with their score + reasons.
  def similar_pairs(memories)
    pairs = []
    memories.each_with_index do |a, i|
      memories[(i + 1)..].each do |b|
        assessment = assess(a, b)
        pairs << assessment if assessment[:score] >= @min_score
      end
    end
    pairs
  end

  def assess(a, b)
    title = title_similarity(a.title, b.title)
    tag = tag_similarity(a.tags, b.tags)

    score = if a.tags.present? && b.tags.present?
      (TITLE_WEIGHT * title) + (TAG_WEIGHT * tag)
    else
      title
    end

    reasons = []
    reasons << "similar title" if title >= 0.5
    reasons << "shared tags" if tag >= 0.5

    {a: a, b: b, score: score.round(3), reasons: reasons}
  end

  # Union-find over the qualifying pairs: transitively-similar memories collapse
  # into one cluster. A cluster's score/reasons come from its strongest pair.
  def build_clusters(memories, pairs)
    parent = memories.to_h { |m| [m.id, m.id] }
    find = ->(id) {
      root = id
      root = parent[root] while parent[root] != root
      root
    }
    union = ->(x, y) { parent[find.call(x)] = find.call(y) }

    pairs.each { |pair| union.call(pair[:a].id, pair[:b].id) }

    grouped = memories.group_by { |m| find.call(m.id) }.values.select { |group| group.size > 1 }

    grouped.map do |group|
      ids = group.map(&:id).to_set
      cluster_pairs = pairs.select { |p| ids.include?(p[:a].id) && ids.include?(p[:b].id) }
      best = cluster_pairs.max_by { |p| p[:score] }

      Cluster.new(
        score: best[:score],
        reasons: cluster_pairs.flat_map { |p| p[:reasons] }.uniq,
        memories: group
      )
    end
  end

  def title_similarity(a, b)
    ta = trigrams(a)
    tb = trigrams(b)
    jaccard(ta, tb)
  end

  def tag_similarity(a, b)
    sa = normalize_tags(a)
    sb = normalize_tags(b)
    jaccard(sa, sb)
  end

  def trigrams(str)
    normalized = normalize(str)
    return Set.new if normalized.length < 3

    (0..normalized.length - 3).map { |i| normalized[i, 3] }.to_set
  end

  def normalize(str)
    str.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  def normalize_tags(tags)
    Array(tags).map { |tag| tag.to_s.downcase.strip }.reject(&:blank?).to_set
  end

  def jaccard(a, b)
    return 0.0 if a.empty? || b.empty?

    (a & b).size.to_f / (a | b).size
  end
end
