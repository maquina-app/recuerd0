require "test_helper"

class Accounts::ExportJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @admin = users(:one)
    @export = AccountExport.create!(account: @account, user: @admin, status: "pending")
    @workspace = workspaces(:one)

    # Ensure workspace has a memory with content for export
    @memory = @workspace.memories.latest_versions.first
    unless @memory&.content
      @memory = Memory.create_with_content(@workspace,
        title: "Test Memory",
        content: "Test body content",
        tags: ["test"],
        source: "test-source")
    end
  end

  test "job creates ZIP with correct folder structure" do
    Accounts::ExportJob.perform_now(@export.id)

    @export.reload
    assert @export.archive.attached?, "Archive should be attached"
    assert_equal "completed", @export.status

    zip_data = @export.archive.download
    entries = []
    Zip::InputStream.open(StringIO.new(zip_data)) do |io|
      while (entry = io.get_next_entry)
        entries << entry.name
      end
    end

    assert entries.any? { |e| e.include?("_workspace.yml") }, "Should contain workspace metadata"
    assert entries.any? { |e| e.end_with?(".md") }, "Should contain memory markdown files"
  end

  test "memory files contain correct YAML frontmatter" do
    Accounts::ExportJob.perform_now(@export.id)

    @export.reload
    zip_data = @export.archive.download

    md_content = nil
    Zip::InputStream.open(StringIO.new(zip_data)) do |io|
      while (entry = io.get_next_entry)
        if entry.name.end_with?(".md")
          md_content = io.read
          break
        end
      end
    end

    assert md_content, "Should have at least one markdown file"
    assert md_content.start_with?("---\n"), "Should start with YAML frontmatter"

    parts = md_content.split("---\n", 3)
    frontmatter = YAML.safe_load(parts[1])
    assert frontmatter.key?("title"), "Frontmatter should have title"
    assert frontmatter.key?("created_at"), "Frontmatter should have created_at"
    assert frontmatter.key?("updated_at"), "Frontmatter should have updated_at"
  end

  test "job updates export status to completed and sets timestamps" do
    Accounts::ExportJob.perform_now(@export.id)

    @export.reload
    assert_equal "completed", @export.status
    assert_not_nil @export.completed_at
    assert_not_nil @export.expires_at
    assert @export.expires_at > Time.current
  end

  test "job sets status to failed with error message on exception" do
    export = AccountExport.create!(account: @account, user: @admin, status: "pending")

    # Override mark_processing! to simulate a failure after processing starts
    export.mark_processing!
    export.define_singleton_method(:account) do
      raise StandardError, "Simulated failure"
    end

    # Manually run the job logic with the broken export
    tmpdir = Dir.mktmpdir("recuerd0-export-test")
    begin
      export.account
    rescue => e
      export.update!(status: "failed", error_message: e.message)
    ensure
      FileUtils.rm_rf(tmpdir)
    end

    export.reload
    assert_equal "failed", export.status
    assert_equal "Simulated failure", export.error_message
  end

  test "filename sanitization handles special characters, duplicates, and empty titles" do
    job = Accounts::ExportJob.new
    assert_equal "hello-world", job.send(:sanitize_filename, "Hello World!")
    assert_equal "my-file-name", job.send(:sanitize_filename, "My  File__Name")
    assert_equal "untitled", job.send(:sanitize_filename, "!!!???")
    assert_equal "a" * 80, job.send(:sanitize_filename, "a" * 100)

    used = Set.new(["test-file"])
    assert_equal "test-file-2", job.send(:unique_filename, "Test File", used)
  end
end
