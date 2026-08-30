module PinsHelper
  # Pins belong to a USER, not to an account, so every pin field in the API has
  # to be resolved against Current.user — which token auth does set
  # (Authentication#authenticate_via_token assigns Current.user = access_token.user).
  #
  # Loaded once per request as a flat index rather than per record, for two
  # reasons: a user holds at most PIN_LIMIT pins so it is one small query, and
  # the JSON views render collections where a per-row `pins` association would
  # be an N+1 (or, worse, silently empty).
  def user_pins_index
    return @user_pins_index if defined?(@user_pins_index)

    @user_pins_index =
      if Current.user
        Current.user.pins.pluck(:pinnable_type, :pinnable_id, :created_at)
          .each_with_object({}) { |(type, id, at), index| index[[type, id]] = at }
      else
        {}
      end
  end

  # A memory version is a separate record, but the pin lives on the ROOT
  # memory. memories#index and the browse endpoint both swap each row for its
  # current version before rendering, so resolving against the record's own id
  # would report every versioned memory as unpinned.
  def pinned_at_for(record)
    id = record.respond_to?(:parent_memory_id) ? (record.parent_memory_id || record.id) : record.id

    user_pins_index[[record.class.name, id]]&.utc
  end

  def pinned_for?(record)
    pinned_at_for(record).present?
  end

  # An unpin toast that carries its own way back.
  #
  # `toast_flash_messages` renders a bare title, so the Undo affordance needs a
  # hand-built toast. It replaces the plain notice rather than sitting beside it
  # — two stacked toasts for one action is worse than the silence it fixes.
  # Rendered with a longer duration than the 5s default because the user has to
  # read a name and decide.
  def pin_undo_toast
    payload = flash[:undo_pin]
    return nil if payload.blank?

    title = flash[:notice].presence || t("pins.destroy.destroyed", title: "")
    href = create_pin_path(pinnable_type: payload["type"], pinnable_id: payload["id"])

    toast(:default, title,
      duration: 10000,
      description: (t("pins.destroy.undo_unavailable", limit: User::PIN_LIMIT) if pin_undo_is_fragile?),
      content: capture {
        concat render("components/toast/action",
          label: t("pins.destroy.undo"),
          href: href,
          method: :post,
          data: {pin_focus_target: "undo"})
      })
  end

  # The unpin just freed a slot, so can_pin_more? is always true here — testing
  # it would make the warning dead code. What matters is whether the user was
  # at the cap before unpinning: they are now one slot short of it, so pinning
  # anything else closes this undo for good.
  def pin_undo_is_fragile?
    return false unless Current.user

    Current.user.pinned_items_count >= User::PIN_LIMIT - 1
  end

  # The notice is folded into the undo toast when there is one, so rendering it
  # again through the flash would duplicate it.
  def toaster_flash_exclusions
    base = [:invitation_url, :new_token, :undo_pin]
    flash[:undo_pin].present? ? base + [:notice] : base
  end
end
