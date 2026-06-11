# Product

## Register

brand

> The primary design surface is the marketing/brand layer (landing home, marketing
> and security layouts, public pages) — design IS the product there. The repo also
> contains a product app (workspaces, memories editor, search, profile/account)
> built on `maquina_components`; when working on those surfaces, override to the
> `product` register per task. Brand is the default because positioning and first
> impression are where the work and the stakes currently are.

## Users

**AI-augmented developers (primary).** Professional developers, 25–45, who use AI
coding tools (Claude Code, Cursor, ChatGPT) daily and maintain 3–10 active projects.
They are tired of re-explaining architecture, conventions, and decisions at the start
of every session. They value control, privacy, and tools that slot into an existing
workflow. Comfortable self-hosting and configuring API tokens. They read READMEs,
think in REST APIs and Bearer tokens, and distrust hype.

**Technical leads & documentation owners (secondary).** Responsible for a single
source of truth that keeps every team member's AI tools aligned on the same
conventions. Care about consistency and onboarding new devs without starting from zero.

**Solo creators / indie hackers & the privacy-conscious (tertiary).** Switch between
multiple client projects and AI tools; or work in regulated environments where
proprietary context can't leave the network.

When they hit the marketing surface they are evaluating: *"Is this a serious tool
built by people who care, or another AI-hype wrapper?"* The page has seconds to answer.

## Product Purpose

Recuerd0 is a self-hosted knowledge base for organizing, versioning, and serving
project knowledge to AI coding tools via a REST API. It is the deliberate middle
layer between scattered CLAUDE.md files and opaque, auto-extracted AI memory.

Humans write, organize, and version their project context into workspaces of
markdown memories; any AI tool consumes it through a simple authenticated API. One
curated source of truth, accessible everywhere, version-controlled as the thinking
evolves.

**The category it creates.** The LLM-memory space splits into automated
infrastructure (Mem0, Claude-Mem, SimpleMem — auto-extracted, opaque, developer-SDK
only) and code-level tooling (CLAUDE.md, CTX, platform features — vendor-locked, no
versioning, no team sharing). No product occupies the middle: a human-friendly web
app where a person organizes context into workspaces, writes and versions markdown
memories, and serves them to *any* tool via API. Recuerd0 is **"the Notion for LLM
context"** — human-curated, tool-agnostic, version-controlled. The marketing surface
must teach this distinction, because the audience's default mental model is
"another AI memory thing," and that framing is exactly wrong.

**The four gaps it fills** (use as concrete proof, not slogans): (1) no human-centric
context tool exists — everything else is automated or CLI-only; (2) cross-tool
portability — the same knowledge feeds Claude Code, Cursor, ChatGPT, and scripts via
REST; (3) version-controlled context evolution — flat branching, "like Git for
context"; (4) small-team context sharing — account multi-tenancy with shared
workspaces, so a whole team's AI tools read from one playbook.

**Real material the brand surface can show** (concrete > abstract): workspaces with
active/archived/deleted states and pinning; markdown memories with tags, source, and
rendered/raw preview; flat-branch versioning with consolidation; SQLite FTS5 search
(safe phrase search in-browser, raw AND/OR/NOT + `title:`/`body:` filters via API);
Bearer-token REST API with scoped read/write tokens, rate limiting, and Link-header
pagination; full account export as a markdown ZIP; a `recuerd0` CLI; MCP/agent
integration; and PWA install. Stack as a trust signal: Rails 8 + SQLite, zero
external dependencies, self-hosted via Kamal.

Success for the brand surface: a developer lands, immediately understands this is a
human-curated (not AI-magic) tool, grasps the new-category distinction, trusts the
craft, and either starts self-hosting or reads the docs/API. Success is comprehension
and credibility, not vanity metrics.

## Brand Personality

Three words: **precise, human, quietly confident.**

Voice is that of a senior engineer who values clarity over cleverness and has seen
enough hype cycles to trust simple tools used well. Composed, not breathless. The
human is always the decision-maker; AI tools are useful instruments, never the hero.

- **Direct** — say what it does, not what it could do.
- **Technical but never gatekeeping** — REST APIs, SQLite, markdown used naturally.
- **Lowercase brand** — always `recuerd0`, never capitalized.
- **Honest about scope** — intentionally small; says so proudly. No apology for being simple.

Emotional goal: replace the feeling of *losing control* (AI generating abandoned
patterns, context scattered across five systems) with *calm, organized clarity* —
you decide what matters, and everything falls in line.

Reusable anchors: "The knowledge base your AI tools deserve." · "You decide what your
AI tools know." · "Your server. Your data. Your context." · "Curate once, access everywhere."

## Anti-references

This should NOT look or read like:

- **A generic SaaS dashboard landing.** No hero-metric template (big number + small
  label + gradient accent), no identical icon-heading-text card grids repeated down
  the page, no tiny uppercase tracked eyebrow above every section, no numbered
  `01 / 02 / 03` section scaffolding by reflex.
- **An "AI product" / chatbot.** No chat-bubble framing, no "AI-powered," "intelligent,"
  "magic," or auto-extraction story. The human curates; the machine consumes. AI is
  never the protagonist.
- **Enterprise / heavy admin.** No toolbar overload, no dense clutter, no 300-words-to-
  say-nothing copy, no buzzwords (synergy, paradigm, ecosystem, leverage, unlock,
  supercharge, 10x, seamless, frictionless, disrupt, game-changer).
- **Consumer-flashy.** No playful over-animation, no decorative glassmorphism, no
  gradient text. Motion is intentional and restrained; the register is a precise
  developer tool with calm confidence.

Banned vocabulary (from the Brand Voice guide): intelligent, smart, magic,
AI-powered, leverage, unlock, supercharge, 10x, revolutionary, game-changer,
seamless, frictionless, disrupt, automagically.

## Design Principles

1. **The human is the hero, not the AI.** Every layout, headline, and illustration
   should put the developer in the driver's seat. The tool serves their judgment; it
   does not replace it.
2. **Practice the restraint we preach.** The product is "simple tools used well." The
   marketing must embody that — earn each element, cut hype, let whitespace and
   precise type carry confidence. The page is proof of the philosophy.
3. **Concrete over abstract.** Show real workflows (organizing a decision, versioning
   a convention, an actual API call) instead of vague promises. Specificity builds
   trust with a technical audience.
4. **Quiet confidence, not volume.** Authority comes from craft and clarity, not from
   shouting "revolutionary." If it reads like a pitch deck, it's wrong.
5. **Ownership and control are the throughline.** Self-hosted, your data, your
   context, tool-agnostic. These are the emotional and rational core — reinforce them
   everywhere rather than burying them in a feature list.

## Accessibility & Inclusion

Target **WCAG 2.1 AAA where feasible**, AA as the non-negotiable floor:

- Body text aims for 7:1 contrast (AAA); never below 4.5:1. Large/bold text never
  below 3:1. Placeholder and muted text held to body-text contrast, not a faint gray.
  The brand green `oklch(0.600 0.190 150)` is mid-tone — verify it against light
  backgrounds and darken toward ink for body-weight text on tint.
- Full keyboard operability with visible focus rings (`--ring`, brand green).
- `prefers-reduced-motion: reduce` honored for every animation — crossfade or instant
  fallback, never a blank gated reveal.
- Don't rely on the brand hue alone to carry meaning (color-blind safe): pair color
  with text, icon, or shape for status (success/warning/error/info already have
  distinct foregrounds in the token set).
- Semantic HTML, labeled controls, and respectful of the developer audience's use of
  screen readers and high-contrast modes.
