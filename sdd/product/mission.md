# Product Mission

## Pitch

Recuerd0 is a personal knowledge management application that helps individuals organize and retrieve markdown-formatted memories by providing workspace-based organization, versioning, and full-text search.

## Users

### Primary Customers

- **Knowledge Workers:** People who need to capture, organize, and retrieve information across projects
- **Personal Users:** Individuals managing personal notes, ideas, and references

### User Personas

**Individual Knowledge Worker** (25-55)
- **Role:** Professional or hobbyist managing multiple areas of knowledge
- **Context:** Single-user, personal knowledge base
- **Pain Points:** Information scattered across apps, difficulty finding past notes, no version history
- **Goals:** Centralized knowledge repository, quick retrieval, organized structure

## The Problem

### Fragmented Knowledge

Notes and memories spread across multiple apps and files make it hard to build a coherent knowledge base.

**Our Solution:** Workspace-based organization with pinning for quick access to important items.

### Lost History

Edits to notes are often destructive with no way to see or restore previous versions.

**Our Solution:** Flat versioning model where any version can spawn new versions and history can be consolidated.

## Differentiators

### Simplicity-First Architecture

Unlike complex note-taking apps, we use the One Person Framework philosophy with SQLite for everything - no external dependencies, simple deployment.

### Memory Versioning

Unlike typical notes apps that overwrite content, we provide full version history with the ability to branch from any version.

## Key Features

### Core Features

- **Workspaces:** Organize memories into logical containers with archive and soft-delete support
- **Memories:** Markdown-formatted notes with tags, source tracking, and full-text search
- **Versioning:** Full version history with flat branching from any version
- **Pinning:** Quick access to up to 10 important workspaces or memories

### Advanced Features

- **Full-Text Search:** FTS5 trigram search across all memories
- **Soft Delete:** 30-day retention window with restore capability
- **Archive:** Pause workspaces without deleting them
