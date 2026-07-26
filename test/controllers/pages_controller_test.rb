require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET start renders the getting started guide without authentication" do
    get start_url

    assert_response :success
    assert_select "body.marketing"
    assert_select "title", text: "Getting Started"
    assert_select ".doc-header .header-section", text: "Getting Started"
    assert_select "h1", text: "Getting Started"

    assert_select ".doc-sidebar a[href='#path'][data-section='path']", text: "From zero to working"
    assert_select ".doc-sidebar a[href='#doors'][data-section='doors']", text: "Three doors, one knowledge base"
    assert_select ".doc-sidebar a[href='#shape'][data-section='shape']", text: "What you start with"
    assert_select "#path h2", text: "From zero to working"
    assert_select "#doors h2", text: "Three doors, one knowledge base"
    assert_select "#shape h2", text: "What you start with"
    assert_select "#shape .resource-header p",
      text: "Every new account includes My Workspace with four memories in a deliberate reading order: " \
        "_MAP, Continuation Brief, _INDEX — Decisions, and D001 — the first decision."
    assert_select "#path h3", text: "1. Create a token"
    assert_select "#path h3", text: "2. Install and connect the CLI"
    assert_select "#path h3", text: "3. Import what you already know"
    assert_select "#path h3", text: "4. Install the skill"
    assert_select "#path h3", text: "5. Connect over MCP"
    assert_includes response.body, "propose → review → commit"
    assert_select "#path .endpoint-head", text: /3\. Import what you already know/ do
      assert_select "p",
        text: /Run recuerd0 workspace list to find the workspace ID\./
    end
    assert_includes response.body, "there is no token to copy"
    assert_includes response.body, "./.claude/skills"
    assert_select "#path a[href='#{recuerd0_mcp_skill_path}']", text: "download the MCP skill"
    assert_select "#shape h3", text: "D001 — the first decision"
    assert_select "#shape h3", text: "When it grows"
    assert_select "#shape p", text: /A hub is a routing-table memory for crowded territory/
    assert_includes response.body, "Hub — Payments"

    assert_select "#path a[href='#{profile_path(anchor: "access-tokens")}']", text: "Access Tokens"
    assert_select "#doors a[href='#{cli_path}']"
    assert_select "#doors a[href='#{mcp_path}']"
    assert_select "#shape a[href='https://github.com/maquina-app/recuerd0/blob/main/docs/blueprint.md']"
    assert_select ".code-block[data-controller='clipboard']", count: 4
    assert_select ".code-block button[data-action='clipboard#copy']", count: 4
    assert_select ".code-block code[data-clipboard-target='source']", count: 4

    import_heading = css_select("#path .endpoint-head").find do |heading|
      heading.at_css("h3")&.text&.strip == "3. Import what you already know"
    end
    import_commands = import_heading.next_element.at_css("code[data-clipboard-target='source']").text.lines.map(&:strip)
    assert_equal(
      [
        "recuerd0 workspace list",
        "recuerd0 import propose ./vault --workspace 12 --pretty",
        "# Review import.plan.yaml, then commit the plan you approved",
        "recuerd0 import commit import.plan.yaml --yes --pretty"
      ],
      import_commands
    )
  end

  test "GET start renders without hosted-service links in single-tenant mode" do
    original_multi_tenant = Rails.application.config.multi_tenant
    Rails.application.config.multi_tenant = false

    get start_url

    assert_response :success
    assert_select "a[href='#{pricing_path}']", count: 0
    assert_select "a[href='#{terms_path}']", count: 0
    assert_select "a[href='#{privacy_path}']", count: 0
    assert_select "a[href='#{license_path}']", count: 0
    assert_select "a[href='#{new_registration_path}']", count: 0
  ensure
    Rails.application.config.multi_tenant = original_multi_tenant
  end

  test "marketing navigation lists Getting Started before API Docs" do
    get pricing_url

    assert_response :success
    assert_select ".nav-links" do
      links = css_select("a").map { |link| [link.text.strip, link["href"]] }
      assert_operator links.index(["Getting Started", start_path]), :<, links.index(["API Docs", api_docs_path])
    end
    assert_select ".nav-overlay-links" do
      links = css_select("a").map { |link| [link.text.strip, link["href"]] }
      assert_operator links.index(["Getting Started", start_path]), :<, links.index(["API Docs", api_docs_path])
    end
  end

  test "authenticated application navigation leads References with Getting Started and a rocket" do
    sign_in_as(users(:one))
    get workspaces_url

    assert_response :success
    references = css_select("[data-sidebar-part='group']").find do |group|
      group.at_css("[data-sidebar-part='group-label']")&.text&.strip == "References"
    end
    assert references, "Expected a References sidebar group"

    first_link = references.at_css("[data-sidebar-part='menu-item']:first-child a")
    assert_equal "Getting Started", first_link.at_css("span").text.strip
    assert_equal start_path, first_link["href"]
    assert_equal "_blank", first_link["target"]
    assert first_link.at_css("svg"), "Expected Getting Started to render an icon"
    assert_includes first_link.to_html, "M4.5 16.5"
  end

  test "GET terms renders terms of service without authentication" do
    get terms_url
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "GET privacy renders privacy policy without authentication" do
    get privacy_url
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "GET pricing renders pricing page without authentication" do
    get pricing_url
    assert_response :success
  end

  test "GET license renders license page without authentication" do
    get license_url
    assert_response :success
    assert_select "h1", "License"
  end

  test "GET api docs distinguishes raw REST search from MCP and workspace search" do
    get api_docs_url

    assert_response :success
    assert_select "#search h3", text: "REST Search Memories"
    assert_includes response.body, "release notes"
    assert_includes response.body, "raw multi-term FTS5 query"
    assert_select "a[href='/mcp#memory-search']"
    assert_includes response.body,
      "When the requesting user has no pinned memories in the workspace, the endpoint returns " \
        "the most recently updated memories instead of an empty list; context_source reports " \
        "pins or recent."
    assert_select "#get-workspace-context", text: /pinned_memories.*deprecated/m
    assert_select "#get-workspace-context", text: /stats\.returned_pinned.*deprecated/m
  end

  test "GET MCP docs renders the safe phrase and exact-tag search contract" do
    get mcp_url

    assert_response :success
    assert_select ".doc-sidebar a[href='#mcp-skill']", text: "MCP skill"
    assert_select "#mcp-skill h2", text: "MCP skill"
    assert_select "#mcp-skill p",
      text: "MCP clients do not have the CLI installer, so download the MCP skill and add it to your client."
    assert_select "#mcp-skill a[href='#{recuerd0_mcp_skill_path}']",
      text: "download the MCP skill"
    assert_select "#memory-search h3", text: "Memory search"
    assert_includes response.body, "case-insensitive whole-tag equality"
    assert_includes response.body, "Matching is substring-level (trigram tokenizer)"
    assert_includes response.body, "<code>rank</code> matches <code>ranking</code>"
    assert_includes response.body, "Queries under three characters"
    assert_includes response.body, "relevance"
    assert_select "a[href='/api-docs#search']"
  end

  test "GET CLI docs includes the skills command" do
    get cli_url

    assert_response :success
    assert_select ".doc-sidebar a[href='#cmd-skills']", text: "skills"
    assert_select "#cmd-skills h3", text: "skills"
    assert_select "#cmd-skills code", text: /recuerd0 skills install/
    assert_select "#cmd-skills code", text: /--global/
    assert_select "#cmd-skills code", text: /--target/
    assert_select "#cmd-skills code", text: /--force/
  end

  test "GET CLI docs uses the account select command" do
    get cli_url

    assert_response :success
    assert_select "#cmd-account code", text: /recuerd0 account select <name>/
    assert_select "#cmd-account tr" do
      assert_select "td:first-child code", text: "select"
      assert_select "td:nth-child(2)", text: "Set the active account."
    end
    assert_not_includes css_select("#cmd-account").first.text, "account default"
  end

  test "GET agents docs links to the CLI skills alternative" do
    get agents_url

    assert_response :success
    assert_select "#claude-code-plugin a[href='#{cli_path}']", text: "CLI page"
    assert_select "#claude-code-plugin code", text: "recuerd0 skills install"
    assert_includes response.body, "drops the same skill into"
    assert_includes response.body, "./.claude/skills"
    assert_select "#claude-code-plugin p",
      text: /It installs the recuerd0 skill — a model-invoked skill/
    assert_not_includes response.body, "It installs the <code>remember</code> skill"
  end
end
