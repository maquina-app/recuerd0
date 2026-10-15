module MemoriesHelper
  # "v7–v9", or "v9" for a single version.
  def version_range_label(versions)
    [versions.first, versions.last].uniq.map(&:version_label).join("–")
  end
end
