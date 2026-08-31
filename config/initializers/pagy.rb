# Pagy 43 resolves nearly everything from the request, so this file only carries
# what differs from its defaults.
#
# There is no :overflow option any more. An out-of-range page is no longer an
# error to catch: Offset#initialize assigns empty page variables and points
# #previous at the last page, which is the graceful degradation the old
# `overflow = :last_page` was reaching for.

# Default records per page (Pagy's own default is 20).
Pagy::OPTIONS[:limit] = 10

# Page links in the series, current page included: [1, :gap, 8, "9", 10, :gap, 36].
# Renamed from :size in 43 — a count of slots, not a size.
Pagy::OPTIONS[:slots] = 7
