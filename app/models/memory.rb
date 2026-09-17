class Memory < ApplicationRecord
  include Pinnable
  include Searchable
  include Embeddable

  belongs_to :workspace, touch: true, counter_cache: true
  belongs_to :parent_memory, class_name: "Memory", optional: true
  has_one :content, dependent: :destroy
  has_many :child_versions, class_name: "Memory", foreign_key: "parent_memory_id", dependent: :destroy
  has_many :outgoing_links, class_name: "MemoryLink", foreign_key: :from_memory_id, dependent: :destroy
  has_many :incoming_links, class_name: "MemoryLink", foreign_key: :to_memory_id, dependent: :destroy

  # Serialize tags as an array - Rails 7+ syntax
  serialize :tags, coder: JSON, type: Array

  # Inherit workspace lifecycle state
  delegate :archived?, :deleted?, :active?, to: :workspace

  # Categories
  CATEGORIES = %w[decision discovery preference general].freeze
  DEFAULT_CATEGORY = "general"

  # The whole vocabulary of obsolescence. A memory carrying any of these tags is
  # retired knowledge: hidden from search, listings and MCP retrieval unless the
  # caller asks for it back with include=obsolete. Matching is case-insensitive
  # and whole-tag — "deprecated-api" is a normal tag.
  OBSOLETE_TAGS = %w[obsolete superseded deprecated].freeze

  # Scopes
  scope :latest_versions, -> { where(parent_memory_id: nil) }

  # Account-scoped, and only workspaces a person can still work in — the set any
  # cross-workspace list should start from. Qualified order because joining
  # workspaces makes a bare updated_at ambiguous.
  scope :in_active_workspaces_of, ->(account) {
    in_active_workspaces.where(workspaces: {account_id: account.id})
  }

  # The workspace half on its own, for a scope that is already account-scoped
  # (pins, a search relation) and only needs the inactive ones dropped.
  scope :in_active_workspaces, -> {
    joins(:workspace).where(workspaces: {archived_at: nil, deleted_at: nil})
  }

  # Memories a soft-deleted workspace is holding are unreachable until the
  # workspace is restored; an archived workspace stays readable.
  scope :in_undeleted_workspaces, -> {
    joins(:workspace).where(workspaces: {deleted_at: nil})
  }
  scope :recently_updated, -> { order(Arel.sql("memories.updated_at DESC")) }
  scope :preloaded, -> { includes(:content, :workspace, :child_versions) }
  scope :versions_of, ->(memory) { where(parent_memory_id: memory.id) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? && CATEGORIES.include?(cat) }

  # Exact, case-sensitive tag match. Mirrors the API's proven predicate from
  # MemoryFilterable#apply_tags_filter (deliberately case-sensitive — unlike the
  # search scope's COLLATE NOCASE tag equality). Uses a bound placeholder, so
  # the tag string is never interpolated into SQL.
  scope :by_tag, ->(tag) {
    next all if tag.blank?
    where("EXISTS (SELECT 1 FROM json_each(memories.tags) WHERE json_each.value = ?)", tag)
  }

  OBSOLETE_PREDICATE =
    "EXISTS (SELECT 1 FROM json_each(memories.tags) WHERE LOWER(json_each.value) IN (?))".freeze

  # The negated mirror of by_tag: excludes any memory carrying at least one
  # obsolete tag. Case-insensitive (unlike by_tag) because the vocabulary is
  # ours, not the user's. Bound placeholders, no interpolation; no JOIN and no
  # ORDER BY, so it composes with every other scope in any order.
  scope :without_obsolete, -> {
    where(
      "NOT #{OBSOLETE_PREDICATE}",
      OBSOLETE_TAGS
    )
  }

  # The positive half, for counting what without_obsolete withheld. Same
  # correlated subquery, not a NOT IN over the table.
  scope :only_obsolete, -> { where(OBSOLETE_PREDICATE, OBSOLETE_TAGS) }

  SEARCH_SORTS = %w[relevance updated created title].freeze

  # Within-workspace and MCP search. Long-enough queries combine the safe,
  # phrase-wrapped FTS relation with exact tag equality. The derived FTS relation
  # keeps rank available to the outer, already-scoped Memory relation.
  scope :search, ->(query) {
    q = normalize_search_query(query)
    return all if q.blank?

    exact_tag = sanitize_sql_array([
      "EXISTS (" \
        "SELECT 1 FROM json_each(memories.tags) AS memory_tags " \
        "WHERE memory_tags.value = ? COLLATE NOCASE" \
      ")",
      q
    ])

    if q.length < Searchable::MIN_QUERY_LENGTH
      where(exact_tag).reorder(updated_at: :desc, id: :desc)
    else
      fts_matches = unscoped
        .full_search(q)
        .reorder(nil)
        .select("memories.id AS memory_id", "memories_search.rank AS rank")

      joins(
        "LEFT JOIN (#{fts_matches.to_sql}) AS memory_search_matches " \
        "ON memory_search_matches.memory_id = memories.id"
      )
        .where("memory_search_matches.memory_id IS NOT NULL OR #{exact_tag}")
        .reorder(
          Arel.sql("CASE WHEN memory_search_matches.memory_id IS NULL THEN 1 ELSE 0 END ASC"),
          Arel.sql("memory_search_matches.rank ASC"),
          Arel.sql(
            "CASE WHEN memory_search_matches.memory_id IS NULL THEN memories.updated_at END DESC"
          ),
          Arel.sql("memories.id DESC")
        )
    end
  }

  scope :ordered_by, ->(sort) {
    case sort
    when "relevance" then all
    when "updated" then reorder(updated_at: :desc, id: :desc)
    when "created" then reorder(created_at: :desc, id: :desc)
    when "title" then reorder(Arel.sql("LOWER(memories.title) ASC"), id: :asc)
    else raise ArgumentError, "sort must be resolved before ordering"
    end
  }

  def self.normalize_search_query(query)
    query.to_s.strip
  end

  def self.resolve_sort(requested_sort, query:)
    normalized_query = normalize_search_query(query)
    requested = requested_sort.to_s

    return requested if %w[updated created title].include?(requested)
    return normalized_query.present? ? "relevance" : "updated" if requested == "relevance"

    normalized_query.present? ? "relevance" : "updated"
  end

  # Validations
  validates :title, length: {maximum: 255}
  validates :version, presence: true, numericality: {greater_than: 0}
  validates :category, presence: true, inclusion: {in: CATEGORIES}

  # Callbacks
  before_validation :set_version, on: :create

  def self.create_with_content(workspace, attributes)
    memory = workspace.memories.build(
      attributes.slice(:title, :tags, :source, :category, :default_pinned).compact
    )

    transaction do
      memory.save!
      memory.create_content!(body: attributes[:content].presence || "")
    end

    memory
  rescue ActiveRecord::RecordInvalid
    memory
  end

  def update_with_content(attributes)
    transaction do
      update!(attributes.slice(:title, :tags, :source, :category))

      next unless attributes.key?(:content)

      content_body = attributes[:content].to_s
      if content_body.blank? && content&.body&.content.present?
        errors.add(:content, :blank_overwrite)
        raise ActiveRecord::RecordInvalid, self
      end

      if content
        content.update!(body: content_body)
      else
        create_content!(body: content_body)
      end
    end
    sync_root_category!
    sync_root_tags!

    self
  rescue ActiveRecord::RecordInvalid
    self
  end

  # Override pinning to respect workspace state
  def can_be_pinned?
    workspace.active?
  end

  # Check if this is the root version (no parent)
  def root_version?
    parent_memory_id.nil?
  end

  # Get the root memory (parent of all versions)
  def root_memory
    parent_memory_id.present? ? parent_memory : self
  end

  # Pins always attach to the root, never to a version.
  #
  # memories#show renders any version at its own URL and hands that record to
  # shared/_pin_button, so pinning while reading v2 used to create a pin on v2.
  # That pin then pointed at a frozen snapshot: it kept showing v2 while the
  # memory moved on, it disagreed with pinned_by? everywhere else (which asks
  # the root), and consolidating versions destroyed the row out from under it.
  def pin_target
    root_memory
  end

  # Get all versions of this memory (including self if root)
  def all_versions
    if root_version?
      workspace.memories.where(
        "(id = ? OR parent_memory_id = ?)",
        id, id
      ).order(:version)
    else
      parent_memory.all_versions
    end
  end

  # Returns the latest (highest version number) version of this memory
  def current_version
    if root_version?
      if child_versions.loaded?
        child_versions.max_by(&:version) || self
      else
        child_versions.order(version: :desc).first || self
      end
    else
      root_memory.current_version
    end
  end

  # Check if this is the current (latest) version
  def current_version?
    self == root_memory.current_version
  end

  # Resolve to the current version if this is a root with children, otherwise return self
  def resolve_current_version
    (root_version? && versioned?) ? current_version : self
  end

  def create_version!(attributes = {})
    root = root_memory

    new_version = root.child_versions.build(
      workspace: root.workspace,
      title: attributes[:title] || title,
      tags: attributes[:tags] || tags,
      source: attributes[:source] || source,
      category: attributes[:category].presence || category
    )

    transaction do
      new_version.save!
      new_version.create_content!(body: attributes[:content] || content&.body&.content.to_s)
      root.touch
    end
    new_version.sync_root_category!
    new_version.sync_root_tags!

    new_version
  rescue ActiveRecord::RecordInvalid
    new_version
  end

  # Keep the root row's category in sync with the current (latest) version's.
  # The root's category is what DB-level filters (by_category) and rollups
  # (group(:category)) read, but every surface displays resolve_current_version's
  # category — without this they diverge and a category filter returns memories
  # whose serialized category contradicts the filter.
  def sync_root_category!
    root = root_memory
    current_category = root.current_version.category
    root.update_column(:category, current_category) if root.category != current_category
  end

  # Keep the root row's tags in sync with the current (latest) version's.
  # The workspace list scopes latest_versions (root rows) but cards display the
  # current version's tags; without this the by_tag filter reads the root's stale
  # tags and would miss a versioned memory whose displayed tag differs. Mirrors
  # sync_root_category! and is called at the same sites.
  def sync_root_tags!
    root = root_memory
    current_tags = root.current_version.tags
    root.update_column(:tags, current_tags) if root.tags != current_tags
  end

  # Human-readable version label
  def version_label
    "v#{version}"
  end

  # Ruby-side twin of the without_obsolete scope, for views and for the
  # in-Ruby collections (merge candidates, top_tags) that have no relation left
  # to filter. sync_root_tags! keeps a root's tags equal to the current
  # version's, so obsolescence is always read off the root row.
  def obsolete?
    tags.any? { |tag| OBSOLETE_TAGS.include?(tag.to_s.downcase) }
  end

  # Check if this memory has any versions (either parent or children)
  def versioned?
    child_versions.any? || parent_memory.present?
  end

  # Consolidate versions: keep this version and destroy all others.
  #
  # Order matters and used to be wrong. child_versions is dependent: :destroy,
  # so destroying the old root cascades into every remaining child — including
  # THIS one when consolidating onto a version. The survivor has to be detached
  # from its parent before the others are destroyed, and its ids captured up
  # front because all_versions resolves differently once it is a root.
  def consolidate_versions!
    transaction do
      doomed_ids = all_versions.where.not(id: id).pluck(:id)

      if parent_memory_id.present?
        # Pins are dependent: :destroy too, so a pin on the outgoing root would
        # vanish along with it — a pin the user never touched.
        adopt_pins_from(Memory.where(id: doomed_ids))
        update!(parent_memory_id: nil, version: 1)
      end

      Memory.where(id: doomed_ids).destroy_all
    end
  end

  # Re-home pins from records that are about to be destroyed, keeping one pin
  # per user (a user may have pinned both the root and a version before pins
  # were normalized to the root).
  def adopt_pins_from(doomed)
    Pin.where(pinnable_type: "Memory", pinnable_id: doomed.select(:id)).find_each do |pin|
      if pins.exists?(user_id: pin.user_id)
        pin.destroy!
      else
        pin.update!(pinnable_id: id)
      end
    end
  end

  # Cross-workspace "see also" links
  def linked_memory_ids
    outgoing_links.pluck(:to_memory_id) + incoming_links.pluck(:from_memory_id)
  end

  # Deleted-workspace memories are dropped: a link is a retrieval path like any
  # other, and deletion has to mean the same thing through every door. Archived
  # ones are kept and carry their workspace state in the payload.
  def linked_memories
    Memory.where(id: linked_memory_ids).in_undeleted_workspaces.includes(:content, :workspace)
  end

  def links_count
    outgoing_links.size + incoming_links.size
  end

  # Display title with fallback for untitled memories
  def display_title
    title.presence || I18n.t("models.memory.untitled")
  end

  private

  def set_version
    self.version = next_version_number
  end

  def next_version_number
    if parent_memory_id.present?
      root_memory.all_versions.maximum(:version).to_i + 1
    else
      1
    end
  end
end
