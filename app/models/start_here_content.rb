module StartHereContent
  MEMORIES = [
    {
      title: "Why recuerd0",
      tags: ["getting-started", "overview"],
      pinned: true,
      content: <<~MARKDOWN
        # Why recuerd0

        Your AI tools forget everything. Every. Single. Session.

        You explain your architecture, your naming conventions, your team's decisions — and the next morning, it's all gone. Context engineering has become a core developer skill, yet there's no dedicated tool for it. You're using scattered files and copy-paste as makeshift solutions.

        ## What recuerd0 does

        recuerd0 is a knowledge base for your AI tools. You organize project context into **workspaces**, write it down as **memories** in Markdown, and serve it to any LLM through a REST API or CLI.

        - **Workspaces** group context by project, team, or topic
        - **Memories** hold the knowledge — architecture decisions, coding conventions, debugging guides, API patterns
        - **Versions** track how your knowledge evolves over time
        - **Search** finds anything across all workspaces with full-text search
        - **Pins** keep your most important memories visible

        ## How it helps

        - **Stop re-explaining.** Write it once, serve it to every tool — Claude Code, Cursor, ChatGPT, or anything that makes HTTP requests.
        - **Stay aligned.** Your whole team's AI tools read from the same playbook.
        - **Keep control.** Self-hosted, your server, your data. No context leaves your infrastructure.

        Human-curated memory, machine-accessible context. You decide what your AI tools know.
      MARKDOWN
    },
    {
      title: "Quick Manual",
      tags: ["getting-started", "manual"],
      pinned: false,
      content: <<~MARKDOWN
        # Quick Manual

        A quick reference for managing your recuerd0 account.

        ## Account Settings

        Go to **Account** in the sidebar to view or update your account name. Only admins can modify account settings or delete the account. Deleted accounts enter a 30-day retention period before permanent removal.

        ## User Profile

        Click your email in the sidebar to access your profile. You can update your email address and password here.

        ## Inviting Users

        Admins can invite up to 5 users per account:

        1. Go to **Account** in the sidebar
        2. Click **Invite User** to generate an invitation link
        3. Share the link — it expires in 7 days
        4. The invited user creates their own password on the invitation page

        Invited users join as **members**. Only the first user (account creator) is an admin.

        ## Personal Access Tokens

        Tokens let you access recuerd0 via the API or CLI:

        1. Go to **Access Tokens** in the sidebar
        2. Click **New Token**
        3. Choose a permission level:
           - **Read only** — can only read workspaces and memories
           - **Full access** — can create, update, and delete
        4. Copy the token immediately — it won't be shown again

        Tokens are rate-limited to 100 requests per minute.

        ## Exporting Data

        You can export all your account data:

        1. Go to **Account** in the sidebar
        2. Click **Export Data**
        3. A background job generates a ZIP file with all workspaces and memories
        4. Download it when ready

        The export includes all workspaces, memories, content, and metadata in JSON format.
      MARKDOWN
    },
    {
      title: "The API",
      tags: ["getting-started", "api"],
      pinned: false,
      content: <<~MARKDOWN
        # The API

        recuerd0 provides a REST API for programmatic access to workspaces and memories.

        ## Authentication

        All requests require a Bearer token in the `Authorization` header:

        ```
        Authorization: Bearer YOUR_TOKEN
        ```

        Create tokens in the web UI under **Access Tokens**. Two permission levels: `read_only` (GET only) and `full_access` (all operations).

        ## Rate Limits

        100 requests per minute per token. Exceeding the limit returns `429 Too Many Requests` with a `Retry-After` header.

        ## Key Endpoints

        **Workspaces**
        - `GET /workspaces.json` — list all workspaces
        - `POST /workspaces.json` — create a workspace
        - `PATCH /workspaces/:id.json` — update a workspace

        **Memories**
        - `GET /workspaces/:id/memories.json` — list memories in a workspace
        - `POST /workspaces/:id/memories.json` — create a memory
        - `PATCH /workspaces/:id/memories/:id.json` — update a memory
        - `DELETE /workspaces/:id/memories/:id.json` — delete a memory

        **Versions**
        - `POST /workspaces/:id/memories/:id/versions.json` — create a new version

        **Search**
        - `GET /search.json?q=<query>` — full-text search across all memories

        Search supports FTS5 operators: `AND`, `OR`, `NOT`, `"exact phrase"`, `title:term`, `body:term`, and parentheses for grouping.

        ## Error Format

        All errors follow a consistent format:

        ```json
        {
          "error": {
            "code": "NOT_FOUND",
            "message": "Resource not found",
            "status": 404
          }
        }
        ```

        See the full API documentation at `/api-docs` for detailed request and response examples.
      MARKDOWN
    },
    {
      title: "The CLI",
      tags: ["getting-started", "cli"],
      pinned: false,
      content: <<~MARKDOWN
        # The CLI

        The recuerd0 CLI wraps the REST API with multi-account support and structured output.

        ## Installation

        ```
        brew install maquina-app/homebrew-tap/recuerd0-cli
        ```

        Also available via apt, dnf, scoop, `go install`, or from source.

        ## Quick Start

        ```bash
        # 1. Add your account
        recuerd0 account add personal --api-url https://your-server.com --token YOUR_TOKEN

        # 2. List workspaces
        recuerd0 workspace list

        # 3. Create a memory
        recuerd0 memory create --workspace 1 --title "Auth patterns" --content "# Auth\\nUse Bearer tokens..."

        # 4. Search across everything
        recuerd0 search "authentication"
        ```

        ## Key Commands

        | Command | Description |
        |---------|-------------|
        | `account add/list/remove` | Manage server connections |
        | `workspace list/create/archive` | Manage workspaces |
        | `memory create/show/update/delete` | Manage memories |
        | `version create/list` | Manage memory versions |
        | `search <query>` | Full-text search with FTS5 operators |

        Use `--content -` to pipe content from stdin:

        ```bash
        cat notes.md | recuerd0 memory create --workspace 1 --title "Notes" --content -
        ```

        ## Configuration

        - **Global config:** `~/.config/recuerd0/config.yaml` — manage multiple accounts
        - **Project-local config:** `.recuerd0.yaml` in your project root — set defaults per directory

        Resolution order: CLI flags > environment variables > project config > global config.

        See the full CLI reference at `/cli` for all commands and options.
      MARKDOWN
    },
    {
      title: "The Agent",
      tags: ["getting-started", "agent"],
      pinned: false,
      content: <<~MARKDOWN
        # The Agent

        recuerd0 provides persistent, searchable memory for AI coding agents. Query context on demand instead of cramming everything into project files.

        ## The Three Layers

        | Layer | Role | Scope |
        |-------|------|-------|
        | `MEMORY.md` | Quick cheat sheet — linting rules, conventions, gotchas | Single project |
        | `recuerd0` | Deep knowledge — architecture, patterns, decisions, debugging | Cross-project |
        | `Transcripts` | Session logs — raw history for later mining | Single session |

        Keep MEMORY.md for quick hits. Use recuerd0 for everything else.

        ## Project Setup

        ```bash
        # 1. Create a workspace for your project
        recuerd0 workspace create --name "my-rails-app"

        # 2. Add a .recuerd0.yaml to your project root
        echo "account: personal\\nworkspace: 1" > .recuerd0.yaml
        ```

        Add a hint to your CLAUDE.md so the agent knows recuerd0 is available:

        ```
        ## Project Knowledge
        Deep project knowledge is stored in recuerd0.
        Search with: recuerd0 search "<query>"
        Read with: recuerd0 memory show --workspace 1 <id>
        ```

        ## Workflows

        - **Pre-session context** — search for relevant knowledge before starting a task
        - **Capture knowledge** — save discoveries and patterns during a session
        - **Archive transcripts** — pipe session logs into recuerd0 for later mining
        - **Track decisions** — use versions to record how decisions evolve over time

        ## Integrations

        recuerd0 works with any tool that supports HTTP or shell commands:

        - **Claude Code** — native plugin available
        - **Cursor** — CLI commands in terminal or REST API via custom tools
        - **ChatGPT** — REST API via custom GPT actions
        - **Custom scripts** — direct REST API with curl, Python, Ruby, or anything

        See the full agents guide at `/agents` for detailed workflows and examples.
      MARKDOWN
    }
  ].freeze
end
