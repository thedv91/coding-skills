# Code health — HIGH (hygiene items LOW)

Default severity: **HIGH** for structure, error handling, dead code, naming,
complexity, and elegance; **LOW** for the hygiene items at the end. Apply to
every changed file. Test quality lives in `tests.md`; dependency changes in
`dependencies.md`.

## Structure & cohesion

- Each function does one thing; extract a named function when a fragment can be
  grouped and explained by its own name (Refactoring: Extract Function), or when
  a function mixes unrelated concerns or exceeds a reasonable length for the
  codebase.
- New code follows existing module boundaries and layering — no business logic
  leaking into controllers/views, no DB calls from the UI layer. Reviewers
  check that the pieces of the change interact sensibly and belong in the
  codebase (Google: design).
- No duplicated logic that an existing utility already covers (DRY — every
  piece of knowledge has one authoritative representation); `grep` before
  adding a helper.

## Error handling

- Errors are handled the way the surrounding code handles them (same pattern:
  thrown, returned, Result type) — not silently swallowed.
- No empty `catch {}` that hides failures; at minimum log or rethrow with
  context.
- Failures of I/O, network, and parsing are accounted for, not assumed to
  succeed.

```js
// BAD
try { await save(x); } catch {}
// GOOD
try { await save(x); } catch (err) { logger.error("save failed", { err }); throw err; }
```

## Dead code & leftovers

- No commented-out code blocks left behind (Refactoring: Remove Dead Code).
- No unreachable branches or unused variables/imports/parameters introduced by
  the change.
- No debug artifacts shipped: `console.log`, `debugger`, scratch endpoints.

## Naming & readability

- Names communicate what a thing is or does without being so long they are hard
  to read (Google: naming). They match codebase conventions (case style, domain
  terms).
- Booleans read as predicates (`isReady`, `hasAccess`); avoid negated names
  (`notDisabled`).
- Magic relationships are named — no opaque single-letter vars outside tight
  loops.
- Comments explain *why* the code exists, not *what* it does; the code itself
  should show the what (Google: comments).

## Complexity

- Code that can't be understood quickly by readers, or that is likely to cause
  bugs, is "too complex" — flag it (Google: complexity).
- Deep nesting is flattened with early returns where the codebase does so
  (Refactoring: Replace Nested Conditional with Guard Clauses).
- A change that sharply raises a function's cyclomatic complexity — McCabe's
  count of linearly independent paths, which grows with each decision point and
  drives the number of test cases needed — is flagged.
- No premature abstraction or over-engineering for needs that don't exist yet;
  solve the known problem now (Google: over-engineering; matches "do the
  minimum").

## Elegance

Correct is the floor, not the bar. There is no perfect code, only better code,
and review exists to improve overall code health (Google: standard of code
review) — code that works but is clumsy still earns a finding when the move
clearly improves clarity. The goal is the clearest expression of the intent.

- **Says what it means:** the shape of the code mirrors the shape of the
  problem; a reader grasps intent without tracing every line.
- **No needless ceremony:** redundant temporaries, double negations, manual
  loops where a single map/filter/reduce reads cleaner, reinventing a stdlib or
  existing-util one-liner.
- **Right tool:** uses the language's idiom and the codebase's existing
  abstraction instead of a verbose hand-rolled equivalent.
- **Symmetry:** parallel cases are written in parallel form; similar things look
  similar, different things look different.
- **Minimal surface:** the simplest signature that does the job — fewest
  parameters, narrowest types, no flags that fork the function into two.

```js
// BAD — works, but clumsy and over-built
let result = [];
for (let i = 0; i < users.length; i++) {
  if (users[i].active === true) { result.push(users[i].name); }
}
// GOOD — intent is the code
const result = users.filter((u) => u.active).map((u) => u.name);
```

Hold elegance findings to the same >80% confidence bar; when "clumsy" is merely
a personal style preference and the code is already clear, leave it out (that is
a style nit per the skill's confidence rules).

## Propose the move, not just the problem

Every structural finding states the concrete remedy in its `Fix:`, not only the
complaint. Name the move; where one applies, use Fowler's refactoring name so
the author can look it up. Common moves:

- Replace type-based conditional sprawl with a typed model / dispatch
  (Refactoring: Replace Conditional with Polymorphism), or break a tangled
  condition into named parts (Refactoring: Decompose Conditional).
- Collapse duplicate branches into one clear path (Refactoring: Consolidate
  Duplicate Conditional Fragments).
- Separate orchestration from business logic.
- Move feature-specific logic out of a shared module (and vice versa).
- Reuse the canonical helper instead of a near-duplicate.
- Delete a pass-through wrapper that adds only indirection (Refactoring: Inline
  Function / Remove Middle Man).
- Extract a helper or split an over-large file into focused units (Refactoring:
  Extract Function).

A refactor that only relocates code without reducing the conceptual load is not
an improvement — say so rather than rubber-stamping it.

## Hygiene — LOW

General engineering hygiene. Report only when it meaningfully helps; do not
pad the review with these.

### TODOs & temporary code

- TODO/FIXME/HACK left in the change has an owner or a tracking reference, not a
  bare note.
- No temporary scaffolding, mock data, or feature toggles left enabled by
  accident.

### Magic values

- Repeated literals (limits, keys, status strings, timeouts) are named constants
  rather than inline magic numbers/strings.
- Deploy-varying config — credentials, hostnames, backing-service URLs — lives in
  the environment, not hardcoded in business logic (12-Factor: Config). Litmus
  test: the repo could be open-sourced without leaking secrets.

```js
// BAD
if (retries > 3) ...
// GOOD
const MAX_RETRIES = 3;
if (retries > MAX_RETRIES) ...
```

### Imports & formatting

- Imports follow the project's ordering/grouping convention; no unused imports.
- No reformatting of untouched lines that bloats the diff.
- Follows the project's linter/formatter rather than a personal style.

### Logging & observability

- Log levels are appropriate (no `error` for normal flow, no noisy `info` in hot
  paths).
- Logs carry enough context to debug but no sensitive data (see `core/security.md`).

### Documentation

- Public APIs, exported functions, and non-obvious decisions have a short
  comment explaining the **why**, kept in sync with the code.
- README / docs updated when the change alters usage or configuration.
- User-facing changes have a changelog entry under the right category — Added,
  Changed, Deprecated, Removed, Fixed, Security (Keep a Changelog). Changelogs
  are for humans: note what changed and why, not every commit.

### PR hygiene

- The change is scoped to its stated purpose — unrelated refactors are split
  out. A CL should be one self-contained change (Google: small CLs).
- Large mechanical changes are separated from logic changes so each is
  reviewable on its own.
- **Size signals** (judgment calls, not hard limits — Google: small CLs):
  ~100 lines is usually a reasonable size; ~1000 lines is usually too large and
  signals splitting the PR or extracting modules. File spread counts too: a
  200-line change in one file may be fine, but the same spread across 50 files
  is usually too large. When in doubt, err smaller — reviewers rarely complain
  that a CL is too small.
- Commit/PR titles follow Conventional Commits — `type(scope): description`,
  with `feat`/`fix` mapping to MINOR/PATCH and `!` or a `BREAKING CHANGE:`
  footer flagging incompatible changes (Conventional Commits).
- Generated files, build output, and lockfiles are intentional, not accidental.

## Sources

- [Google Eng Practices — What to look for in a code review](https://google.github.io/eng-practices/review/reviewer/looking-for.html) — design, functionality, complexity, tests, naming, comments, consistency, over-engineering.
- [Google Eng Practices — The Standard of Code Review](https://google.github.io/eng-practices/review/reviewer/standard.html) — approve once the change improves overall code health; no "perfect" code.
- [Refactoring catalog (Martin Fowler)](https://refactoring.com/catalog/) — index of named refactorings and their summaries.
- [Refactoring — Extract Function](https://refactoring.com/catalog/extractFunction.html) — group a fragment into a function named for its intent.
- [Refactoring — Replace Conditional with Polymorphism](https://refactoring.com/catalog/replaceConditionalWithPolymorphism.html) — turn type-based conditionals into polymorphic dispatch.
- [Refactoring — Replace Nested Conditional with Guard Clauses](https://refactoring.com/catalog/replaceNestedConditionalWithGuardClauses.html) — flatten nesting with early returns.
- [Cyclomatic complexity (Wikipedia)](https://en.wikipedia.org/wiki/Cyclomatic_complexity) — McCabe's measure of linearly independent paths; grows per decision point, drives test-case count.

- [Google Engineering Practices — Small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html) — CL size guidance: ~100 lines reasonable, ~1000 too large, file spread matters
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — commit message format, types, scope, breaking changes, SemVer mapping
- [The Twelve-Factor App — Config](https://12factor.net/config) — store deploy-varying config in the environment; strict separation of config from code
- [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) — changelog principles and the Added/Changed/Deprecated/Removed/Fixed/Security categories
