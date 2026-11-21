# Remembers how a person last looked at the Workspaces, Memories and Pinned
# lists, in one browser-only cookie that Rails reads and writes. It holds
# display state and nothing else: never an account, user or token, and never
# used to authorize or scope anything — every query still goes through
# Current.account / Current.user.
#
# For each key: a valid explicit param wins and is stored, a blank param clears
# the stored value, an invalid param is ignored. Without a param the stored
# value is used if it is still valid, otherwise the page default (nil here).
# JSON and Bearer-token requests read params only and never touch the cookie.
module ListPreferences
  extend ActiveSupport::Concern

  COOKIE = :recuerd0_preferences
  # Writing past the 4 KB cookie limit raises CookieOverflow; skipping the
  # write only means the preference is not remembered.
  MAX_BYTES = 3_000

  # Read once when a section has no view of its own yet, so nobody loses the
  # density they picked before the unified cookie existed.
  LEGACY_VIEW_COOKIES = {workspaces: :recuerd0_workspace_view, memories: :recuerd0_memory_view}.freeze

  WORKSPACE_VIEWS = %w[list grid].freeze
  WORKSPACE_SORTS = %w[name memories].freeze
  WORKSPACE_QUERY_LIMIT = 80
  MEMORY_VIEWS = %w[cards compact].freeze

  private

  def workspace_list_preferences(sort: false, mine: false)
    {
      view: preference(:workspaces, :view) { it.presence_in(WORKSPACE_VIEWS) } || "list",
      query: preference(:workspaces, :q) { it.strip.first(WORKSPACE_QUERY_LIMIT).presence },
      sort: (preference(:workspaces, :sort) { it.presence_in(WORKSPACE_SORTS) } if sort),
      mine: (mine && preference(:workspaces, :mine) { {"1" => true, "0" => false}[it] }) || false
    }
  end

  def preference(section, key)
    if params.key?(key)
      raw = params[key]
      return clear_preference(section, key) if raw.blank?

      value = yield(raw) if raw.is_a?(String)
      return store_preference(section, key, value) unless value.nil?
    end

    stored = param_form(stored_preference(section, key))
    yield(stored) if stored
  end

  # Stored values go through the same normalizer as params, so they get the
  # param spelling back (mine is saved as true, workspace_id as an integer).
  # Anything else — an array, a hash, a float — reads as nothing saved.
  def param_form(value)
    case value
    when String then value
    when Integer then value.to_s
    when true then "1"
    when false then "0"
    end
  end

  def stored_preference(section, key)
    return unless list_preferences_enabled?

    stored = stored_list_preferences.fetch(section.to_s, {})[key.to_s]
    if stored.nil? && key == :view && (legacy = LEGACY_VIEW_COOKIES[section])
      stored = cookies[legacy]
    end
    stored
  end

  def store_preference(section, key, value)
    if value == false
      clear_preference(section, key)
    else
      write_list_preferences(section) { it[key.to_s] = value }
    end
    value
  end

  def clear_preference(section, key)
    write_list_preferences(section) { it.delete(key.to_s) }
    nil
  end

  def write_list_preferences(section)
    return unless list_preferences_enabled?

    values = stored_list_preferences[section.to_s] ||= {}
    yield values
    json = stored_list_preferences.to_json
    return if json.bytesize > MAX_BYTES

    cookies[COOKIE] = {value: json, expires: 1.year, httponly: true, same_site: :lax}
  end

  # Anything malformed, truncated or of the wrong shape reads as "nothing
  # saved", section by section.
  def stored_list_preferences
    @stored_list_preferences ||= begin
      parsed = JSON.parse(cookies[COOKIE].to_s)
      parsed.is_a?(Hash) ? parsed.select { |_, values| values.is_a?(Hash) } : {}
    rescue JSON::ParserError
      {}
    end
  end

  def list_preferences_enabled?
    request.format.html? && !extract_bearer_token
  end
end
