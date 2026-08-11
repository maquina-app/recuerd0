# Hybrid retrieval v0 — flagged embeddings + RRF fusion behind `list_memories`

## Summary

Add local, root-keyed memory embeddings and semantic/RRF retrieval solely to
`Mcp::Tools.list_memories`.

The existing lexical path remains untouched and is used whenever the server flag
is off, `retrieval` is absent, `retrieval: "lexical"` is explicit, or the
normalized query is shorter than three characters. No UI, user documentation,
other MCP tool, FTS schema, tokenizer, or existing search ordering changes.

## Implementation

### Configuration, provider, and persistence

- Add `informers ~> 1.3.0`; use its documented
  `sentence-transformers/all-MiniLM-L6-v2` embedding pipeline, which returns 384
  dimensions. Do not add a vector extension or direct ONNX dependency.
- Read these once at boot:
  - `config.x.hybrid_retrieval`: `ENV.fetch("HYBRID_RETRIEVAL", "false") == "true"`.
  - Provider/model/dimensions configuration, defaulting to `informers`,
    `sentence-transformers/all-MiniLM-L6-v2`, and `384`.
  - Production cache directory: `Rails.root.join("storage", "informers")`;
    development/test leave `cache_dir` unset so Informers uses its normal cache.
- Introduce a provider factory and interface exposing `model`, `dimensions`, and
  `embed(text)`. Resolve configured provider names through an explicit registry;
  unknown providers raise a configuration error.
- Memoize the Informers pipeline per process. Normal application providers pass
  `local_files_only: true`; only the backfill task may construct a remote-enabled
  provider. Therefore no request or write callback can download model weights.
- Add `memory_embeddings` with:
  - Unique, non-null `memory_id`, foreign-keyed to `memories` with delete cascade.
  - Non-null `model`, `content_hash`, binary `vector`, and timestamps.
  - No vector or secondary similarity index.
- `MemoryEmbedding` packs/unpacks vectors as portable little-endian float32 using
  `pack("e*")`/`unpack("e*")`; validate provider output dimensions and finite
  numeric values before persistence.

### Inline maintenance and backfill

- Add an `Embeddable` lifecycle concern without changing `Searchable` or its FTS
  SQL. Invoke embedding maintenance from the same `after_save_commit` /
  `after_destroy_commit` lifecycle and from `Content`’s existing post-commit
  reindex callback so title, body, and version changes are covered.
- Resolve `root_memory`, then the highest-version child or root exactly as FTS
  does. Embed `newest.title.to_s + "\n\n" +
  newest.content&.body&.content.to_s`, while always storing under the root ID.
- Compute SHA-256 over that exact string. Skip without loading the pipeline only
  when both `content_hash` and `model` match. Otherwise embed first, then
  transactionally delete/reinsert the root row.
- When the flag is off, return before referencing `MemoryEmbedding` or the
  provider. Destroy callbacks likewise perform no application-level embedding
  work.
- Ordinary callback failures must not make existing user writes appear failed
  after commit: remove any now-stale row when possible, log root ID/model/error
  without memory content, and let backfill repair it. Explicit maintenance /
  backfill calls raise and exit nonzero on provider failures.
- Add `search:embed_backfill[workspace_id]`, guarded by the flag before any
  embedding-table access. It processes all roots or one workspace, uses the sole
  remote-enabled provider so the first model download is deliberate, reuses
  hash/model skipping, and prints `N embedded, M unchanged`. A second unchanged
  run must report zero embedded.

### Retrieval and MCP behavior

- Add a `MemoryRetrieval` object returning ranked root IDs from a supplied
  `workspace.memories.latest_versions` relation. Keep these constants together:
  - `SEMANTIC_TOP_K = 50`
  - `RRF_K = 60`
  - `HALF_LIFE_DAYS = 30`
  - `DECAY_FLOOR = 0.25`
- Validate `retrieval` only when the flag is enabled. Absence means lexical;
  explicit blank/null or an unknown value is a `Mcp::ToolError`. When disabled,
  ignore every supplied value, including invalid ones.
- For blank queries, or normalized queries shorter than
  `Searchable::MIN_QUERY_LENGTH`, use the existing path unchanged; short queries
  remain exact-tag-only and never call the provider.
- For queries of at least three characters:
  - `semantic`: embed the query once, scan only current-model embedding rows
    belonging to the supplied workspace/root relation, calculate cosine in Ruby,
    and keep the top 50 by similarity, then `updated_at DESC, id DESC`.
  - `hybrid`: materialize the complete existing `Memory.search(query)` order —
    including tag-only tail — and the semantic top 50. Fuse 1-based ranks with
    `Σ 1 / (60 + rank)`, deduplicate root IDs, and order by fused score, then
    `updated_at DESC, id DESC`.
  - `hybrid_decay`: multiply the fused score of `general` roots by
    `max(0.5 ** (age_days / 30.0), 0.25)`, with age clamped to zero or greater.
    Other categories receive factor `1.0`; re-sort with the same tie-breakers.
- Apply category filtering only after ranked IDs are produced. Then call
  `Memory.resolve_sort` as today:
  - `"relevance"` preserves ranked ID order.
  - `"updated"`, `"created"`, and `"title"` call the existing `ordered_by` scope
    over the ranked candidate relation.
- Materialize and paginate experimental results in Ruby. Compute `total_count`
  after category filtering, preserve current limit/offset clamping and envelope
  math, and serialize current versions exactly as today.
- If an explicit semantic mode cannot load the cached model, return a clear MCP
  tool error instructing the operator to run the backfill; never download,
  silently fall back, or alter lexical results.
- Add only this `list_memories` schema property:
  - String enum: `lexical`, `semantic`, `hybrid`, `hybrid_decay`
  - Description exactly: `internal/experimental; requires server flag`
- Do not alter the `list_memories` description or any other tool definition.

## Test plan

- Make the first feature-code change the regression test: synthetic FTS,
  dual-match, and tag-only memories must produce identical `Memory.search`
  ordering and identical `list_memories` envelopes with the flag off and with the
  flag on but no `retrieval`. Also prove flag-off explicit/invalid retrieval is
  ignored and emits no `memory_embeddings` SQL.
- Use a deterministic injected fake provider for every automated test; assert no
  test constructs the Informers pipeline or downloads model files.
- Persistence tests cover newest-version text under the root ID, title/body
  updates, unchanged hash skipping, model-change re-embedding, flag-off writes,
  callback failure cleanup, and float32 round-trip.
- Retrieval tests cover:
  - Workspace isolation and current-model filtering.
  - The synthetic “checkpoint stalls on the storage mount” / “restore hangs”
    vocabulary gap: lexical misses, semantic and hybrid find it.
  - Hand-computed RRF lists, for example lexical `[A, B, C]` and semantic
    `[C, B, D]`, yielding `C, B, A, D`.
  - Thirty-day half-life, 0.25 floor, non-negative age, and factor `1.0` for
    decision/preference/discovery.
  - Post-retrieval category filtering, explicit sort overrides, stable ties,
    pagination/counts, short-query tag-only behavior, invalid modes, and unchanged
    tool-description text.
- Backfill tests use seeded synthetic workspaces and the fake provider: first run
  embeds, second run skips, workspace scoping works, counts are exact, and
  flag-off invocation aborts before schema access.
- Run the exact local gates:
  - `bin/brakeman --no-pager`
  - `bin/bundler-audit --update`
  - `bin/importmap audit`
  - `bin/rubocop -f github`
  - `RAILS_ENV=test bin/rails db:test:prepare test test:system`
- Build and boot the production image for `linux/amd64`; verify the native gems
  load under Ruby 4. Separately run the backfill against a mounted temporary
  `/rails/storage`, then prove an offline process can load the cached model without
  downloading.

## Rollout, review, and assumptions

- Deploy and migrate with the server flag off. Run a one-off
  `HYBRID_RETRIEVAL=true` backfill against the shared production storage while the
  web process remains off-flag; only enable/restart the server after it succeeds.
  Rollback is setting the flag false and restarting; embeddings and cached weights
  may remain.
- Target `linux/amd64` only for v0. Linux ARM packaging and validation remain
  adoption-phase work even though current live Bundler metadata resolves ARM
  artifacts. Baking weights into the image is likewise deferred unless the
  experiment graduates.
- Keep chunking, API providers, vector indexes, queues, UI/docs exposure,
  per-workspace settings, non-lexical defaults, bench assets, and all other MCP
  tools out of scope.
- Work on `codex/hybrid-retrieval-v0`, run all gates, and push the branch.
- For review, verify `HERDR_ENV=1`, inspect the installed Herdr CLI, start a new
  Codex reviewer in a sibling pane at the same repository, and give it only this
  plan plus `git diff origin/main...HEAD`. The reviewer must use the fresh-context
  Ruby review workflow, run the full gates, and return:
  - `VERDICT: APPROVED` or `VERDICT: BLOCKED`
  - Actionable findings with file/line evidence
  - Commands run and results
  - Scope/plan-compliance assessment
- On `BLOCKED`, fix, rerun gates, repush, and use another fresh-context reviewer.
  After `APPROVED`, run the repository signoff, leave the branch open, and stop.
  Never merge; merging is human-only.
