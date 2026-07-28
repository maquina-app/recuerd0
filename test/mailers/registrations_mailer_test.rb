require "test_helper"

class RegistrationsMailerTest < ActionMailer::TestCase
  setup do
    @user = Account.create_with_user(
      email_address: "welcome@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @workspace = @user.account.workspaces.find_by!(name: "My Workspace")
    @email = RegistrationsMailer.welcome(@user)
  end

  test "welcome email has correct subject and recipients" do
    assert_equal I18n.t("registrations_mailer.welcome.subject"), @email.subject
    assert_equal [@user.email_address], @email.to
    assert_equal ["noreply@recuerd0.ai"], @email.from
  end

  test "welcome email HTML contains branded content" do
    body = @email.html_part.body.decoded
    start_url = Rails.application.routes.url_helpers.start_url(host: "example.com")
    workspace_url = Rails.application.routes.url_helpers.workspace_url(@workspace, host: "example.com")

    assert_match "recuerd0", body
    assert_includes body, "<strong>My Workspace</strong>"
    assert_includes body, start_url
    assert_includes body, "Getting Started guide"
    assert_includes body, workspace_url
    assert_includes body, "Open My Workspace"
    document = Nokogiri::HTML.fragment(body)
    seeded_intro = document.css("p").find { |paragraph| paragraph.text.include?("four seeded memories") }
    assert seeded_intro
    assert_equal seeded_titles, seeded_intro.next_element.css("li").map { |item| item.text.strip }
    assert_equal(
      "The Getting Started guide takes you from zero to your first import in a few minutes.",
      seeded_intro.next_element.next_element.text.strip
    )
    assert_not_includes body, ["five onboarding", "memories"].join(" ")
    assert_not_includes body, ["_", "MAP"].join
    assert_not_includes body, ["_", "INDEX"].join
  end

  test "welcome email text contains key information" do
    body = @email.text_part.body.decoded
    start_url = Rails.application.routes.url_helpers.start_url(host: "example.com")

    assert_match "Welcome to recuerd0", body
    assert_includes body, "My Workspace"
    assert_includes body, "Open My Workspace"
    assert_includes body, start_url
    assert_includes body, "Getting Started: #{start_url}"
    assert_match "never share it, sell it", body
    lines = body.lines.map(&:chomp)
    seeded_intro = lines.index("We created My Workspace for you with four seeded memories:")
    assert seeded_intro
    assert_equal seeded_titles, lines.slice(seeded_intro + 2, 4).map { |line| line.delete_prefix("- ") }
    assert_equal "", lines.fetch(seeded_intro + 6)
    assert_equal(
      "The Getting Started guide takes you from zero to your first import in a few minutes.",
      lines.fetch(seeded_intro + 7)
    )
    assert_not_includes body, ["five onboarding", "memories"].join(" ")
    assert_not_includes body, ["_", "MAP"].join
    assert_not_includes body, ["_", "INDEX"].join
  end

  private

  def seeded_titles
    [
      "Map — how this workspace is kept",
      "Continuation Brief",
      "Index — decisions",
      "D001 — the first decision"
    ]
  end
end
