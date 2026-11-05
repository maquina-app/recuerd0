class Memory < ApplicationRecord
  include Pinnable
  include Searchable
  include Embeddable
  include Ownable

  belongs_to :workspace, touch: true
  belongs_to :parent_memory, class_name: "Memory", optional: true
  has_one :content, dependent: :destroy
  has_many :child_versions, class_name: "Memory", foreign_key: "parent_memory_id", dependent: :destroy, inverse_of: :parent_memory
  # Only the newest child, so a result list can show each memory's current
  # version without loading its history. Preload it; current_version and
  # versioned? read it when loaded.
  has_one :latest_version, -> {
    where("memories.version = (SELECT MAX(siblings.version) FROM memories AS siblings " \
      "WHERE siblings.parent_memory_id = memories.parent_memory_id)")
  }, class_name: "Memory", foreign_key: "parent_memory_id", inverse_of: :parent_memory
  has_many :outgoing_links, class_name: "MemoryLink", foreign_key: :from_memory_id, dependent: :destroy
  has_many :incoming_links, class_name: "MemoryLink", foreign_key: :to_memory_id, dependent: :destroy

  # Serialize tags as an array - Rails 7+ syntax
  serialize :tags, coder: JSON, type: Array
  # Null, not empty, until a root's tags part ways with the current version's.
  serialize :first_version_tags, coder: JSON

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

  # Exact, case-sensitive tag match, for the web filter a tag chip links to (it
  # always carries the tag's own spelling). Typed filters ignore case instead: see
  # MemoryFilterable#apply_tags_filter and the search scope. Uses a bound placeholder,
  # so the tag string is never interpolated into SQL.
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

  # Far above anything real, there to stop one write bloating every list and export.
  # Only checked when the value changes, so a row older than a limit stays editable.
  MAX_TAGS = 50
  MAX_TAG_LENGTH = 100
  MAX_SOURCE_LENGTH = 255
  MAX_CONTENT_BYTES = 1.megabyte

  # The body being written, so the limit can fail on this record: Content is saved
  # after it, and its own invalid record would leave these errors empty.
  attr_accessor :incoming_body

  # Validations
  validates :title, length: {maximum: 255}
  validates :version, presence: true, numericality: {greater_than: 0}
  validates :category, presence: true, inclusion: {in: CATEGORIES}
  validates :source, length: {maximum: MAX_SOURCE_LENGTH}, if: :source_changed?
  validate :tags_within_limits, if: :tags_changed?
  validate :incoming_body_within_limit

  validates :change_note, length: {maximum: 280}

  # Callbacks
  before_validation :set_version, on: :create
  before_validation :drop_repeated_tags
  # memories_count answers "how many memories", and a version is not a memory,
  # so this replaces a counter cache that counted every row.
  after_create :increment_workspace_memories_count, if: :root_version?
  after_destroy :decrement_workspace_memories_count, if: :root_version?

  # Every door refuses an empty memory, so one can never reach an agent. Direct
  # memories.create! is reserved for system-authored rows.
  def self.create_with_content(workspace, attributes)
    memory = workspace.memories.build(
      attributes.slice(:title, :tags, :source, :category, :default_pinned, :created_by).compact
    )
    memory.incoming_body = attributes[:content]

    if attributes[:title].blank? && attributes[:content].blank?
      memory.errors.add(:base, :blank_memory)
      return memory
    end

    transaction do
      memory.save!
      memory.create_content!(body: attributes[:content].presence || "")
    end

    memory
  rescue ActiveRecord::RecordInvalid
    memory
  end

  def update_with_content(attributes)
    self.incoming_body = attributes[:content]

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

  def ownership_record
    root_memory
  end

  # Delete is the one thing a workspace's owner can do to what others put in it.
  def deletable_by?(user)
    manageable_by?(user) || workspace.owned_by?(user)
  end

  # What this version itself held. A root row's own columns follow the current
  # version, for filters and rollups, so v1 has to answer from what it kept.
  def version_tags
    first_version_tags || tags
  end

  def version_category
    first_version_category || category
  end

  # Check if this is the root version (no parent)
  def root_version?
    parent_memory_id.nil?
  end

  # The id a person links to: the root's URL always opens the current version.
  def stable_id
    parent_memory_id || id
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
  # the root), and deleting versions destroyed the row out from under it.
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
      if association(:latest_version).loaded?
        latest_version || self
      elsif child_versions.loaded?
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
      tags: attributes[:tags] || version_tags,
      source: attributes[:source] || source,
      category: attributes[:category].presence || version_category,
      created_by: attributes[:created_by],
      change_note: attributes[:change_note].presence
    )
    new_version.incoming_body = attributes[:content]

    # Omitting content inherits it. Sending it blank is asking to wipe the memory,
    # which update_with_content refuses too.
    if attributes[:content]&.blank? && root.current_version.content&.body&.content.present?
      new_version.errors.add(:content, :blank_overwrite)
      return new_version
    end

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

  # Fingerprint of the current text and fields, carried by the edit form to notice
  # that someone saved while this person was typing. Includes the id, so a new
  # version by anyone counts.
  def edit_digest
    Digest::SHA256.hexdigest([id, title, source, category, tags, content&.body&.content.to_s].to_json)
  end

  # The editor's "Save as new version": the new version, or nil with the reason in
  # errors. Unlike create_version!, whose callers may legitimately copy (restore,
  # or an API client relying on inherited fields), this one refuses a version that
  # records nothing and a blank overwrite of existing content.
  def save_as_new_version(attributes)
    if attributes.key?(:content) && attributes[:content].blank? && content&.body&.content.present?
      errors.add(:content, :blank_overwrite)
    elsif !differs_from?(attributes)
      errors.add(:base, :no_changes)
    else
      version = create_version!(attributes)
      version.errors.each { |error| errors.add(error.attribute, error.message) }
    end

    version if errors.empty?
  end

  # REST and MCP's way in: the same as create_version!, unless the result would
  # repeat the current version. That adds a row to the history and tells a reader
  # nothing, and it is what a retrying agent produces. `ignoring` is for fields the
  # caller did not choose: MCP stamps every call with the client's name as its source.
  def create_changed_version(attributes, ignoring: [])
    return create_version!(attributes) unless repeats_current_version?(attributes.except(*ignoring))

    Memory.new.tap { |version| version.errors.add(:base, :no_changes) }
  end

  # What this row would become with these attributes, as create_version! fills them:
  # a nil or a blank category inherits. Versioning an older row with no changes is
  # not a repeat, because the result differs from the current version.
  def repeats_current_version?(attributes)
    given = attributes.compact
    given = given.except(:category) if given[:category].blank?
    inherited = {title: title, source: source, category: version_category, tags: version_tags, content: content&.body&.content.to_s}

    !root_memory.current_version.differs_from?(inherited.merge(given))
  end

  # Compares what would be stored, so text the save normalizes and tags differing
  # only in case do not read as changes.
  def differs_from?(attributes)
    %i[title source category].any? { |field| attributes.key?(field) && attributes[field].to_s != self[field].to_s } ||
      (attributes.key?(:tags) && self.class.distinct_tags(attributes[:tags]) != self.class.distinct_tags(tags)) ||
      (attributes.key?(:content) &&
        ActionText::Markdown.separate_fences_from_lists(attributes[:content]) != content&.body&.content.to_s)
  end

  # Search and filters treat tags by name, so Deploy and deploy are one tag, and so are
  # " ops " and ops. The first spelling wins.
  def self.distinct_tags(tags)
    Array(tags).map { |tag| tag.to_s.strip }.compact_blank.uniq(&:downcase)
  end

  # Keep the root row's category in sync with the current (latest) version's.
  # The root's category is what DB-level filters (by_category) and rollups
  # (group(:category)) read, but every surface displays resolve_current_version's
  # category — without this they diverge and a category filter returns memories
  # whose serialized category contradicts the filter.
  def sync_root_category!
    root = root_memory
    current_category = root.current_version.category
    return if root.category == current_category

    root.update_columns(category: current_category, first_version_category: root.version_category)
  end

  # Keep the root row's tags in sync with the current (latest) version's.
  # The workspace list scopes latest_versions (root rows) but cards display the
  # current version's tags; without this the by_tag filter reads the root's stale
  # tags and would miss a versioned memory whose displayed tag differs. Mirrors
  # sync_root_category! and is called at the same sites.
  def sync_root_tags!
    root = root_memory
    current_tags = root.current_version.tags
    return if root.tags == current_tags

    root.update_columns(tags: current_tags, first_version_tags: root.version_tags)
  end

  # What changed besides the body, as [field, before, after]. A root that kept no first
  # version value either never differed or dates from before it was kept, and in both
  # cases its own columns say nothing about v1.
  def field_changes_from(previous)
    known = if previous.root_version?
      {category: previous.first_version_category, tags: previous.first_version_tags}.compact
    else
      {category: previous.category, tags: previous.tags}
    end

    {title: previous.title, source: previous.source, **known}.filter_map do |field, before|
      after = self[field]
      [field, before, after] if before.presence != after.presence
    end
  end

  # Human-readable version label
  def version_label
    "v#{version}"
  end

  # Numbers only ever go up, even after a purge.
  def next_version_label
    "v#{root_memory.all_versions.maximum(:version).to_i + 1}"
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
    return true if parent_memory_id.present?

    association(:latest_version).loaded? ? latest_version.present? : child_versions.any?
  end

  # Trim the history to its latest `keep` versions; returns the rows deleted.
  #
  # The root's id is what pins, links, URLs and agents hold, so it survives. The
  # oldest kept version (the anchor) moves into the root row and its own row goes
  # with the doomed children: version numbers are not renumbered, and every other
  # kept child keeps its id.
  def purge_versions!(keep:)
    root = root_memory
    versions = root.all_versions.includes(:content).to_a
    unless keep.is_a?(Integer) && keep.between?(1, versions.size - 1)
      raise ArgumentError, "keep must be an Integer from 1 to #{versions.size - 1}"
    end

    anchor = versions[-keep]
    removed_ids = Memory.rows_removed_by_purge(versions, keep:)

    transaction do
      root.adopt_pins_from(Memory.where(id: removed_ids))
      root.adopt_links_from(removed_ids, version_ids: versions.map(&:id))

      root.update!(anchor.slice(:title, :tags, :source, :category, :version, :created_at)
        .merge(first_version_tags: nil, first_version_category: nil))
      body = anchor.content&.body&.content.to_s
      root.content ? root.content.update!(body: body) : root.create_content!(body: body)

      Memory.where(id: removed_ids).destroy_all
    end

    # Destroying a child deletes the root's FTS row after commit.
    root.rebuild_search_index
    root.sync_root_category!
    root.sync_root_tags!

    removed_ids.size
  end

  # The rows a purge deletes: every doomed child, plus the oldest kept version
  # (the anchor), whose content moves into the root row.
  def self.rows_removed_by_purge(versions, keep:)
    versions.first(versions.size - keep).reject(&:root_version?).map(&:id) << versions[-keep].id
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

  # Move links off rows that are about to be destroyed onto this root. A link to
  # another version of this memory, or to something the root already links to,
  # has nowhere to go and is dropped.
  def adopt_links_from(doomed_ids, version_ids:)
    MemoryLink.where(from_memory_id: doomed_ids).or(MemoryLink.where(to_memory_id: doomed_ids)).to_a.each do |link|
      doomed_side = doomed_ids.include?(link.from_memory_id) ? :from_memory_id : :to_memory_id
      other_id = (doomed_side == :from_memory_id) ? link.to_memory_id : link.from_memory_id

      # normalize_order stores every pair low id first.
      if version_ids.include?(other_id) || MemoryLink.exists?(from_memory_id: [id, other_id].min, to_memory_id: [id, other_id].max)
        link.destroy!
      else
        link.update!(doomed_side => id) # normalize_order re-sorts the pair
      end
    end
  end

  # Cross-workspace "see also" links
  def linked_memory_ids
    return root_memory.linked_memory_ids if parent_memory_id

    outgoing_links.pluck(:to_memory_id) + incoming_links.pluck(:from_memory_id)
  end

  # Deleted-workspace memories are dropped: a link is a retrieval path like any
  # other, and deletion has to mean the same thing through every door. Archived
  # ones are kept and carry their workspace state in the payload.
  def linked_memories
    Memory.where(id: linked_memory_ids).in_undeleted_workspaces.includes(:content, :workspace)
  end

  # Links live on the root, so a version reports its memory's count.
  def links_count
    return root_memory.links_count if parent_memory_id

    outgoing_links.size + incoming_links.size
  end

  # The ids on the far side of the links this user may remove.
  def unlinkable_memory_ids_for(user)
    (outgoing_links + incoming_links).select { |link| link.manageable_by?(user) }.map { |link| link.other_side_id(self) }
  end

  # Display title with fallback for untitled memories
  def display_title
    title.presence || I18n.t("models.memory.untitled")
  end

  private

  def tags_within_limits
    errors.add(:tags, :too_many, count: MAX_TAGS) if tags.size > MAX_TAGS
    errors.add(:tags, :tag_too_long, count: MAX_TAG_LENGTH) if tags.any? { |tag| tag.to_s.length > MAX_TAG_LENGTH }
  end

  def incoming_body_within_limit
    return if incoming_body.to_s.bytesize <= MAX_CONTENT_BYTES

    errors.add(:content, :too_long, count: "1 MB")
  end

  def drop_repeated_tags
    self.tags = self.class.distinct_tags(tags)
  end

  def increment_workspace_memories_count
    adjust_workspace_memories_count(1)
  end

  def decrement_workspace_memories_count
    adjust_workspace_memories_count(-1)
  end

  # Keeps the loaded workspace honest too, as a counter cache would, without
  # leaving it dirty.
  def adjust_workspace_memories_count(by)
    Workspace.update_counters(workspace_id, memories_count: by)
    return if workspace.frozen?

    workspace[:memories_count] += by
    workspace.clear_attribute_changes([:memories_count])
  end

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
