# Code intelligence: codegraph + serena

Applies when the repo root has `.codegraph/` (codegraph — pre-built graph:
source, call paths, blast radius) and/or `.serena/` (serena — live LSP:
symbol-precise navigation and editing). Neither present → ignore this file.
Either present → prefer it over `Grep` / `Glob` / `Read`, and over a blind
`Edit`. The session's tool list is the authority on what each one exposes.

## codegraph orients, serena decides and edits

- **Explore with codegraph.** One `codegraph_explore` returns verbatim source
  - call paths + blast radius; treat that source as read. Serena's
    `get_symbols_overview` → `find_symbol` is the first move only when codegraph
    is absent or stale (~2s watcher lag after a write).
- **Decide with serena.** Before changing anything public, the reference list
  comes from `find_referencing_symbols`. Codegraph's `callers` is incomplete
  (measured ~94% against the LSP in one repo) and `impact` is transitive reach,
  not a fuller list — it recovered none of the misses. Never use either alone
  to answer "where is this used?".
- **Edit with serena.** `replace_symbol_body` / `insert_*_symbol` for whole
  symbols, `replace_content` for a fragment inside a body, `rename_symbol` /
  `safe_delete_symbol` for reference-aware refactors — over hand-matched
  `Edit`; `Edit` only for non-code content (config, data, prose). Fetch the
  body first (`find_symbol include_body=true`) — never guess one.
- **Verify with serena, then the project.** `get_diagnostics_for_file` on each
  touched file, then whatever the project uses for lint / typecheck / tests,
  once at the end.

## Gotchas

- **Homonyms.** Codegraph queried by bare name merges every symbol with that
  name into one answer (4 definitions → 11 "callers", 8 of them for the other
  three). Pass `file` (codegraph `node` / `callers` / `impact` — `explore`
  has no such param and a file name in its query does not pin the file) or
  `relative_path` (serena) whenever the name could exist more than once.
- **Serena edits are `mcp__serena__*` calls.** Hooks matched on `Edit|Write`
  do not fire for them, and their input carries `relative_path`, not
  `file_path` — check the project's `PostToolUse` matcher or run the
  formatter yourself.
- **Serena under `--context claude-code --project-from-cwd`** has no
  `activate_project` (already active; ignore the session-start reminder) and
  no `search_for_pattern` (use `Grep`). Other launch configs may differ.
- **Generated / vendored code** is indexed like everything else — check the
  project's rules before editing anything under a codegen or third-party path.
- **Serena memories** (`list_memories` / `read_memory`) hold per-project notes;
  the project's own human-written docs win on any conflict.
