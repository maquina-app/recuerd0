module Accounts
  class ExportJob < ApplicationJob
    queue_as :default
    discard_on ActiveRecord::RecordNotFound

    def perform(account_export_id)
      export = AccountExport.find(account_export_id)
      export.mark_processing!

      tmpdir = Dir.mktmpdir("recuerd0-export")

      begin
        account = export.account
        account_dir = File.join(tmpdir, sanitize_filename(account.name))
        FileUtils.mkdir_p(account_dir)

        build_workspace_folders(account, account_dir)

        zip_path = File.join(tmpdir, "#{sanitize_filename(account.name)}.zip")
        create_zip(account_dir, zip_path)

        export.archive.attach(
          io: File.open(zip_path),
          filename: "#{sanitize_filename(account.name)}-export-#{Date.current.iso8601}.zip",
          content_type: "application/zip"
        )

        export.mark_completed!
        AccountExportMailer.completed(export).deliver_later
      rescue => e
        Rails.logger.error("[AccountExport] Export ##{export.id} failed: #{e.class}: #{e.message}")
        export.mark_failed!(e.message)
      ensure
        FileUtils.rm_rf(tmpdir)
      end
    end

    private

    def build_workspace_folders(account, account_dir)
      account.workspaces.not_deleted.order(:name).each do |workspace|
        workspace_dir = File.join(account_dir, sanitize_filename(workspace.name))
        FileUtils.mkdir_p(workspace_dir)

        write_workspace_metadata(workspace, workspace_dir)
        export_memories(workspace, workspace_dir)
      end
    end

    def write_workspace_metadata(workspace, workspace_dir)
      metadata = {
        "name" => workspace.name,
        "description" => workspace.description.presence,
        "archived" => workspace.archived?,
        "memories_count" => workspace.memories_count,
        "created_at" => workspace.created_at.iso8601,
        "updated_at" => workspace.updated_at.iso8601
      }.compact

      File.write(File.join(workspace_dir, "_workspace.yml"), metadata.to_yaml)
    end

    def export_memories(workspace, workspace_dir)
      used_filenames = Set.new(["_workspace"])

      workspace.memories.latest_versions.includes(:content, :child_versions).order(:title).each do |root_memory|
        newest = find_newest_version(root_memory)
        filename = unique_filename(newest.display_title, used_filenames)
        used_filenames.add(filename)

        write_memory_file(newest, filename, workspace_dir)
      end
    end

    def find_newest_version(root_memory)
      latest_child = root_memory.child_versions.order(version: :desc).first
      latest_child || root_memory
    end

    def write_memory_file(memory, filename, workspace_dir)
      frontmatter = {
        "title" => memory.title,
        "tags" => memory.tags.presence,
        "source" => memory.source.presence,
        "version" => memory.version,
        "created_at" => memory.created_at.iso8601,
        "updated_at" => memory.updated_at.iso8601
      }.compact

      body = memory.content&.body || ""

      content = "---\n#{frontmatter.to_yaml.sub("---\n", "")}---\n\n#{body}"
      File.write(File.join(workspace_dir, "#{filename}.md"), content)
    end

    def create_zip(source_dir, zip_path)
      Zip::File.open(zip_path, create: true) do |zipfile|
        Dir[File.join(source_dir, "**", "*")].each do |file|
          next if File.directory?(file)
          entry_name = file.sub("#{File.dirname(source_dir)}/", "")
          zipfile.add(entry_name, file)
        end
      end
    end

    def sanitize_filename(name)
      sanitized = name.to_s
        .gsub(/[^a-zA-Z0-9\-_ ]/, "")
        .gsub(/[\s_]+/, "-")
        .squeeze("-")
        .gsub(/\A-|-\z/, "")
        .downcase
        .truncate(80, omission: "")

      sanitized.presence || "untitled"
    end

    def unique_filename(title, used_filenames)
      base = sanitize_filename(title)
      return base unless used_filenames.include?(base)

      counter = 2
      loop do
        candidate = "#{base}-#{counter}"
        return candidate unless used_filenames.include?(candidate)
        counter += 1
      end
    end
  end
end
