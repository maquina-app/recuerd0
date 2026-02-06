# recuerd0 — Brand & Marketing Voice Guide

*How we talk about memory, knowledge, and keeping humans in the loop.*

**Internal Reference · v1.0 · February 2026**

---

## Contents

1. [Brand Position](#01-brand-position)
2. [Core Narrative](#02-core-narrative)
3. [Voice Principles](#03-voice-principles)
4. [Tone Spectrum](#04-tone-spectrum)
5. [Vocabulary & Word Bank](#05-vocabulary--word-bank)
6. [Messaging Framework](#06-messaging-framework)
7. [Audience Personas](#07-audience-personas)
8. [Voice in Action](#08-voice-in-action)
9. [Anti-Patterns](#09-anti-patterns)
10. [Taglines & Headlines](#10-taglines--headlines)

---

## 01 — Brand Position

### What recuerd0 stands for

recuerd0 exists at the intersection of two truths: **AI tools are only as good as the context they receive**, and **humans are the only ones who truly understand what matters**. We don't automate knowledge — we give people the tools to organize it, version it, and hand it to AI on their terms.

This makes us fundamentally different from "AI memory" products that try to figure out what you care about. We believe the human should decide. Always.

> **Positioning statement**
>
> recuerd0 is a self-hosted knowledge base for development teams who use AI tools daily. It gives humans a deliberate, organized way to curate project context — so AI tools get the right knowledge, and humans stay in control of what that knowledge is.

### We are not

An AI product. A chatbot. An "AI memory" that guesses what you need. An automation layer. We are a **human-curated knowledge system** that happens to serve AI tools through an API. The intelligence lives in the team, not in the software.

---

## 02 — Core Narrative

### The story we tell

Every developer who uses AI tools has felt the frustration: you start a new session, and the AI knows nothing. Your architecture decisions, your naming conventions, the patterns your team agreed on last week — gone. So you re-explain. Copy-paste from scattered markdown files. Pray it remembers this time.

This isn't an AI problem. It's a **knowledge management problem**. Your team's accumulated wisdom — the conventions, the decisions, the context that makes code coherent — has no home. It lives in Slack threads, in people's heads, in docs nobody updates.

recuerd0 gives that knowledge a home. **You write it. You organize it. You version it as your thinking evolves.** Then you serve it to any AI tool — Claude Code, Cursor, ChatGPT, your own scripts — through a simple API. One source of truth, accessible everywhere.

The result isn't just better AI output. It's a team that stays aligned on how things are built, with AI tools that reinforce those decisions instead of undermining them.

> **The emotional core**
>
> We speak to the feeling of **losing control** — of AI tools generating patterns you've abandoned, of context scattered across five different systems, of explaining the same thing to a machine for the tenth time. Then we offer **calm, organized clarity**: you decide what matters, and everything falls in line.

---

## 03 — Voice Principles

### How we sound

Our voice reflects our product philosophy: precise, human, and quietly confident. We speak like a senior engineer who values clarity over cleverness — someone who has seen enough hype cycles to know that simple tools, used well, beat complex ones.

### Human-first, always

We never position AI as the hero. The human — the developer, the team lead, the architect — is always the decision-maker. AI tools are useful instruments. recuerd0 keeps the human in the driver's seat.

### Calm authority

We don't shout about revolution or disruption. We speak from experience — the quiet confidence of a tool that does one thing exceptionally well. Our tone is composed, not breathless.

### Concrete over abstract

No vague promises about "unlocking potential." We talk about real workflows: organizing architecture decisions, versioning conventions, searching across project knowledge. Specificity builds trust.

### Honest about scope

recuerd0 is intentionally small in scope — and we say so proudly. It doesn't try to replace your docs, your wiki, or your project management tool. It does one thing: serve curated context to AI tools. We're comfortable with boundaries.

### Developer-native

We speak the audience's language without condescension. REST APIs, Bearer tokens, SQLite, markdown — we use technical terms naturally because our readers think in them. No need to dumb it down or dress it up.

---

## 04 — Tone Spectrum

### Where we land on the dial

Our tone isn't fixed — it shifts depending on context. But it always stays within a band: professional enough for a README, warm enough for a blog post, sharp enough for a tagline.

### We sound like

- A thoughtful senior engineer explaining a system
- A well-edited technical blog post
- Release notes that respect your time
- A colleague who gives you the context you actually need
- Documentation that assumes competence

### We don't sound like

- A startup pitch deck full of superlatives
- A chatbot trying to be your friend
- Marketing copy that says "leverage AI" unironically
- A manifesto about the future of work
- Enterprise software that takes 300 words to say nothing

### Tone by context

| Context | Tone | Example register |
|---------|------|-----------------|
| Landing page | Confident, concise, slightly poetic | "The knowledge base your AI tools deserve" |
| Documentation | Clear, direct, no-nonsense | "All API requests require a Bearer token" |
| Blog / updates | Warm, reflective, human | "We built this because we kept re-explaining" |
| Error messages | Helpful, never blaming | "Query must be at least 3 characters" |
| Social media | Sharp, concrete, no hype | "Your AI forgot your conventions. Again." |

---

## 05 — Vocabulary & Word Bank

### The words we reach for

Language shapes perception. These are the words that define how recuerd0 feels — and the ones we deliberately avoid.

### Core vocabulary

Words that reinforce our brand values: human agency, organization, deliberate action, and control.

**Primary verbs:** curate, organize, preserve, serve, version

**Key nouns:** knowledge, context, memory, workspace, team, decisions, conventions

**Descriptors:** deliberate, aligned, self-hosted, simple, focused, tool-agnostic

**Ownership phrases:** your server, your data, your context

### Words we avoid

These words either over-promise, dehumanize, or belong to a different kind of product.

~~intelligent~~ · ~~smart~~ · ~~magic~~ · ~~automate your…~~ · ~~AI-powered~~ · ~~leverage~~ · ~~unlock~~ · ~~supercharge~~ · ~~10x~~ · ~~revolutionary~~ · ~~game-changer~~ · ~~seamless~~ · ~~frictionless~~ · ~~disrupt~~

### Key phrases

These anchor our messaging and can be reused across contexts:

> **Ownership** — "Your server, your data, your context."

> **Control** — "Human-curated memory, machine-accessible."

> **Simplicity** — "Curate once, access everywhere."

> **Agency** — "You decide what your AI tools know."

---

## 06 — Messaging Framework

### What we say and why

Every piece of communication should ladder up to one of these three pillars. They answer the question: **why should someone care?**

| Pillar | Core message | Supporting proof |
|--------|-------------|-----------------|
| **Human control** | You choose what your AI tools know. Not the other way around. | Manual curation, no auto-extraction, no guessing. The team decides what's canonical. |
| **Team alignment** | Everyone's AI tools use the same playbook — your team's playbook. | Shared workspaces, versioned memories, one source of truth across all AI tools and team members. |
| **Practical simplicity** | One server, one API, zero dependencies. It just works. | Self-hosted Rails 8 + SQLite, Bearer token auth, REST API, works with any LLM tool. |

### The "so what" chain

For any feature, follow this chain to find the human benefit:

**Feature → Benefit → Feeling**

- Versioned memories → Your context evolves with your architecture → **Confidence** that AI tools always have current knowledge, not stale patterns.
- Full-text search → Find any memory in milliseconds → **Relief** that nothing gets lost in an ever-growing knowledge base.
- Workspace organization → Group context by project → **Clarity** that the right AI tool gets the right context, nothing more.

---

## 07 — Audience Personas

### Who we're talking to

Our primary audience is technical — developers and team leads who use AI coding tools daily and feel the friction of context management. Our secondary audience is technical decision-makers evaluating tools for their team.

### 🧑‍💻 The Solo Builder

**Full-stack developer · Uses Claude Code & Cursor daily**

Maintains 2–3 active projects. Tired of copy-pasting the same architecture doc into every AI session. Wants a single source of truth they can point any tool at.

### 👩‍🔧 The Team Lead

**Engineering lead · 4–8 person team**

Watches junior devs get inconsistent AI output because everyone feeds it different context. Wants the whole team's AI tools aligned on the same conventions.

### 🔒 The Privacy-Conscious

**Senior engineer · Enterprise or regulated industry**

Can't send proprietary architecture docs to third-party services. Needs a self-hosted solution where project knowledge never leaves the network.

### ⚡ The Tool Hopper

**Developer · Switches between 3+ AI tools**

Uses ChatGPT for brainstorming, Claude Code for implementation, Cursor for refactoring. Frustrated that context doesn't transfer between any of them.

---

## 08 — Voice in Action

### How it sounds in practice

Each example below includes an annotation explaining *why* the copy works.

---

**Landing page hero:**

> The knowledge base your AI tools deserve. Organize, version, and serve project context to any LLM — from Claude Code to Cursor to ChatGPT. Human-curated memory, instantly accessible via REST API.

*"Deserve" gives agency to the developer's choice. "Human-curated" is the first descriptor. The tools are listed as recipients, not drivers.*

---

**Problem framing:**

> Your AI tools forget everything. Every. Single. Session. Context engineering has become a core developer skill, yet there are no dedicated tools for it. You're using scattered files and copy-paste as makeshift solutions.

*We name the pain concretely. No vague "challenges" — specific frustrations developers recognize immediately.*

---

**Blog post opening:**

> We built recuerd0 because we got tired of explaining our codebase to machines. Not once — every morning. The same architecture decisions, the same naming conventions, the same "we don't use service objects, we use use cases." It felt like onboarding a new junior dev who forgets everything overnight.

*Warm, specific, relatable. Uses the team's actual vocabulary. The machine is the one being trained, not the other way around.*

---

**Feature description:**

> Branch from any version with a flat versioning model. Track how your project knowledge evolves — like Git for context.

*Analogy to a tool the audience already loves. Short. No filler.*

---

**Social post:**

> Your architecture evolved three months ago. Your AI tools are still generating the old patterns. That's not an AI problem — it's a context management problem.

*Reframes the issue. Doesn't blame the AI, doesn't blame the user. Points at the real gap.*

---

## 09 — Anti-Patterns

### What we never do

### Language anti-patterns

- Calling recuerd0 "AI-powered" or "intelligent"
- Implying AI makes decisions for the user
- Using "magic" or "automagically"
- Promising productivity multipliers (10x, etc.)
- Using "just" to minimize complexity
- Enterprise buzzwords: synergy, paradigm, ecosystem

### Tone anti-patterns

- Breathless excitement about AI capabilities
- Fear-mongering about falling behind
- Talking down to the reader's intelligence
- Over-explaining simple concepts
- Being self-deprecating about our scope
- Apologizing for being simple (it's a feature)

### Before / after

| Instead of this | Write this |
|----------------|-----------|
| "Supercharge your AI workflow with intelligent context management" | "Organize your project knowledge. Serve it to any AI tool." |
| "Our AI automatically learns your team's patterns" | "Write down your team's conventions. recuerd0 serves them wherever you need." |
| "Seamlessly integrate with your existing toolchain" | "REST API with Bearer auth. Works with anything that makes HTTP requests." |
| "Unlock the full potential of AI-assisted development" | "Stop re-explaining your codebase. Start preserving." |
| "Built with cutting-edge technology" | "Rails 8, SQLite, zero external dependencies." |

---

## 10 — Taglines & Headlines

### Lines worth reusing

A library of approved headlines and taglines, organized by use case. Mix, match, and adapt as needed.

### Primary taglines

> The knowledge base your AI tools deserve.

> Human-curated memory. Machine-accessible context.

> You decide what your AI tools know.

### Problem-framing headlines

> Your AI tools forget everything. Every. Single. Session.

> Context engineering shouldn't be a copy-paste job.

> Different tools, same context gap.

### Action-oriented headlines

> Stop re-explaining your project. Start preserving.

> Curate once, access everywhere.

> Write it once. Serve it to every tool.

### Trust-building headlines

> Your server. Your data. Your context.

> One API. Zero dependencies. Complete ownership.

> Simple tools, used well, beat complex ones.

### Team-oriented headlines

> Your whole team's AI tools, reading from the same playbook.

> Align your AI tools on what your team actually decided.

> The knowledge stays. The people decide.

---

*recuerd0 · Brand & Marketing Voice Guide · v1.0 · For internal use*
