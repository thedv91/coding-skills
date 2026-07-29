---
description: Review the diff between the current branch and a target branch, understand the project's business logic, and give structured feedback.
argument-hint: "<target-branch> (e.g. main, develop, dev). Empty = the repo's default branch (from origin/HEAD)"
allowed-tools: Bash(git rev-parse:*), Bash(git fetch:*), Bash(git merge-base:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git show:*), Bash(git status:*), Bash(grep:*), Bash(rg:*), Bash(find:*), Bash(ls:*), Bash(cat:*), Bash(yarn test:*), Bash(yarn typecheck:*), Bash(yarn lint:*), Bash(yarn eslint:*), Bash(npm test:*), Bash(npm run test:*), Bash(npm run typecheck:*), Bash(npm run lint:*), Bash(pnpm test:*), Bash(pnpm run test:*), Bash(pnpm typecheck:*), Bash(pnpm lint:*), Bash(pnpm eslint:*), Bash(npx tsc:*), Bash(npx eslint:*), Bash(npx vitest run:*), Bash(npx jest:*), Bash(tsc:*), Bash(eslint:*), Bash(vitest run:*), Bash(jest:*), Bash(pytest:*), Bash(go test:*), Bash(go vet:*), Bash(cargo test:*), Bash(cargo check:*), Bash(cargo clippy:*), Read, Grep, Glob, Skill, mcp__code-review-graph__*, mcp__codegraph__*, mcp__plugin_serena_serena__*, mcp__serena__*
---

# Code Review (business-logic aware)

Target branch to compare against: **$ARGUMENTS** (empty = the repo's default
branch, detected — never assumed to be `main`).

**READ-ONLY.** This command inspects code and runs non-mutating checks only. It
never edits code, never runs a build, codegen, or a formatter in write mode.

## Collect the diff

### 1. Resolve TARGET — before running any diff

TARGET = `$ARGUMENTS` (the branch the user passed). Prefer `$ARGUMENTS` over
positional `$1` — in some harnesses `$1` is not populated and silently renders
empty, which would make a non-default target fall back to the default and review
the wrong branch. If `$ARGUMENTS` is also empty, fall back to the
`<command-args>` value from the invocation wrapper.

If TARGET is still empty, **detect the repo's default branch — do NOT assume
`main`** (many repos merge into `dev`, `develop`, or `master`):

```
git rev-parse --abbrev-ref origin/HEAD   # e.g. "origin/dev" → TARGET = dev
```

If `origin/HEAD` is unset, infer from
`git branch -rl origin/main origin/master origin/dev origin/develop`
(prefer in that order; the patterns must be listed separately — git's pattern
matching does not expand `{a,b}` braces, so a single quoted brace pattern
silently matches nothing) — and only then fall back to `main`. Do NOT rely on
`${1:-main}`-style shell defaulting anywhere. Resolve TARGET yourself, then use
it verbatim below — and record in the report's **Scope & evidence** whether
TARGET was user-supplied or auto-detected.

Now pin down which _ref_ TARGET means, and stop early on the degenerate cases:

```
git rev-parse --abbrev-ref HEAD
git fetch --quiet || echo "FETCH FAILED — origin refs may be stale"
git rev-parse --verify --quiet origin/<TARGET>
git rev-parse --verify --quiet <TARGET>
```

- **Prefer `origin/<TARGET>` whenever it exists.** A local `main`/`dev` is
  routinely stale, and diffing against a stale ref replays commits that are
  already merged upstream as if they were new — every finding on them is a
  phantom. Only fall back to the local ref when there is no remote-tracking one,
  and **say in the report which ref you compared against**.
- **If the fetch failed** — the `FETCH FAILED` marker printed (or git's own
  error did) — `origin/<TARGET>` is only as fresh as the last successful fetch.
  Still prefer it, but state in **Scope & evidence** that the fetch failed and
  the ref may be stale. Don't let the failure stop the review: the `||` marker
  exists precisely so a dead remote degrades to a stale-ref warning, not an
  abort.
- Neither ref exists → list branches (`git branch -a`) and ask the user. STOP.
- The resolved ref **is** the current branch (HEAD == TARGET) → report that there
  is nothing to compare and STOP.

Call the ref you settled on `<REF>` from here on.

### 2. Check for uncommitted work — it is NOT in the diff

```
git status --short
```

`git diff <REF>...HEAD` only sees **committed** work. If the tree is dirty, the
user's newest changes are invisible to that diff — and silently reviewing a stale
snapshot of their branch is worse than not reviewing at all. So:

- Tree clean → proceed.
- Tree dirty → **tell the user which files are uncommitted** and review them too:
  add `git diff HEAD` (unstaged) and `git diff --cached` (staged) to the material
  below, and mark those files in the report's **Scope & evidence** as
  "uncommitted". Never let a dirty file drop out of the review unmentioned.
- **Untracked files (`??` in `git status --short`) appear in NEITHER of those
  diffs** — `git diff` never shows a file git isn't tracking, so a brand-new
  source file silently escapes both the branch diff and the dirty-tree diffs.
  `Read` each untracked source file directly, fold it into the review, and mark
  it "untracked" in **Scope & evidence**. (Skip untracked build output /
  editor droppings — but say you skipped them.)

### 3. Pull the diff

```
git diff --stat -M <REF>...HEAD
git log --oneline <REF>..HEAD
```

Then the full diff, with renames detected and generated/lock files excluded:

```
git diff -M <REF>...HEAD -- . ':(exclude)pnpm-lock.yaml' ':(exclude)package-lock.json' ':(exclude)yarn.lock' ':(exclude)*.lock' ':(exclude)*.snap' ':(exclude)**/_generated/**' ':(exclude)*.min.*'
```

`-M` matters: without it a moved file reads as a whole-file delete plus a
whole-file add, which both inflates the diff and buries the handful of lines that
actually changed inside the move.

**Large-diff guard:** read the `--stat` output first. If the full diff exceeds
~3,000 lines, do NOT dump it in one command — pull it in chunks per
feature/directory (`git diff -M <REF>...HEAD -- <path>`), starting with the files
at the center of the business flow. Excluded generated files are only noted as
present, never reviewed line by line.

If the diff is empty (and the tree is clean) → report "No changes between the
current branch and `<REF>`" and STOP.

### 4. Check target-side drift — the three-dot diff has a blind side

`git diff <REF>...HEAD` diffs from the **merge-base**, so anything that landed on
`<REF>` *after* this branch diverged is invisible to it — and to the blast-radius
scan below, which reads the branch's working tree. That is exactly where semantic
merge conflicts live: a caller added on the target that uses the old contract of
a function this branch just changed merges cleanly and breaks at runtime.

```
git log --oneline HEAD..<REF> -- <paths touched by this branch>
```

- No output → the target hasn't touched the same files; move on.
- Output → the target evolved the same files. `git diff HEAD...<REF> -- <path>`
  on each hit, and check the two sides against each other: does the target-side
  change add/alter a consumer, sibling variant, or contract that this branch's
  change violates (or vice versa)? Flag any such interaction as a finding and
  note the drift check's result in **Scope & evidence**.

### 5. Check the branch's parentage — a stacked branch poisons the diff

If this branch was cut from **another unmerged feature branch** instead of from
`<REF>`, the merge-base with `<REF>` predates the parent's work — so the diff
replays every one of the parent branch's commits as if they were this branch's,
and you end up reviewing (and blaming) someone else's unmerged work.

Read the `git log --oneline <REF>..HEAD` you already pulled and look for the
tells: commit clusters referencing a **different ticket**, a different author's
unrelated series, or subjects that clearly belong to another feature. When in
doubt, `git branch -a --contains <oldest-suspect-commit>` — if another feature
branch contains it, this branch is stacked on it.

Stacked → don't silently review the union. Tell the user the branch appears
stacked on `<parent>`, review **only the commits on top of the parent's** (diff
against the parent tip instead), or — if the layers can't be separated cleanly —
label each finding with the layer it belongs to. Record the split in
**Scope & evidence**.

## Use the skills you already have

The harness lists every available skill in your context, including plugin skills.
**Do not go scanning the filesystem for `SKILL.md` files** — the on-disk scan
misses `~/.claude/plugins/**` (where most skills actually live) and costs a
round-trip to rediscover what you were already told.

From that list, pick up what fits this diff and invoke it with the `Skill` tool:

1. **Code-review skills** (e.g. `review-code-change:review-code-change`,
   `code-review`, `engineering:code-review`) → use their criteria/checklist
   together with the steps below. Prefer their standards where they are more
   detailed than this file.
2. **Domain skills matching the changed files** (e.g. `testing-strategy`,
   `security-and-hardening`, `accessibility-review`, `react-compiler-compliance`,
   or an org's internal skill) → apply their perspective to the parts of the
   diff in their scope.
3. **Report-export skills** (e.g. `docx`, `pdf`) → only if the user asks to
   export a file.

Briefly tell the user which skills you picked up and what for, e.g. _"Applied:
engineering:code-review (checklist), react-compiler-compliance (hooks in the
diff)."_ If none is relevant → skip silently.

## Map the BLAST RADIUS first (mandatory, do not skip)

Before judging any changed line, determine **every place the change reaches**.
Do this deterministically with the code-graph tools — do NOT infer the impact by
reading the changed file and reasoning about who is affected, then stopping at
the first couple of consumers you can picture. The bug is almost always in a
consumer you did not open.

For EACH changed symbol / exported function / prop / derived value / type in the
diff, enumerate its references **with a tool, not from memory**:

1. **Query the graph (preferred).**
   - **`codegraph`** — `codegraph_explore "<changed symbols / file names>"`: read
     the **"Blast radius — what depends on these"** section it prints, plus the
     verbatim source of each consumer (treat that source as already Read).
     `codegraph_callers <symbol>` — direct callers of a function/method.
   - **serena** — `find_referencing_symbols` (name_path + relative_path) — precise
     LSP references; `get_symbols_overview` / `find_symbol` to locate the target.
   - If a **`code-review-graph`** server is connected (`mcp__code-review-graph__*`
     appears in your tool list — it usually is not), it is purpose-built for this:
     `get_minimal_context_tool` for a cheap overview, then
     `get_impact_radius_tool(base="<REF>", detail_level="minimal")` for the
     blast-radius file list. Keep `detail_level="minimal"` — `"standard"` embeds
     the whole impact graph and overflows the token limit on any non-trivial
     change.
2. **Fallback when no graph server is connected:** `grep -rln '<name>' <src>` via
   **Bash** for every changed identifier. Never assume the count; list the files.
   (Use Bash `grep`/`rg`, not a `Grep` tool — several harnesses, including Claude
   Code Desktop, expose no such tool and the call fails outright. `Bash` is in
   this command's allowed tools for exactly this reason.)
3. **Open EVERY site the query returns.** If it lists 3 files, read 3. When two
   surfaces do the same job (desktop ↔ mobile, sibling switch branches, an
   inline path + its detail/hover/tooltip variant), **diff them against each
   other** — divergence between siblings is the #1 bug smell.
   **Wide-blast exception:** for a symbol with more than ~20 references, reading
   every site is not feasible — group the references by surface (route, platform,
   sibling variant), read at least one representative per group plus every site
   adjacent to the changed code, and **state the actual coverage in the report's
   Scope & evidence** (e.g. "read 8 of 41 references, one per surface group")
   instead of implying full coverage.

Then, for each significantly changed file:

4. **Read** the whole file (not just the diff hunk) for the context the changed
   function/class lives in.
5. From the reference set above, specifically check:
   - Callers of the changed function/API — does the change break a contract?
   - Related model/schema/type definitions — how does the data flow?
   - Corresponding tests — were they updated accordingly?
   - Config / business-rule files (constants, rules, validators).
6. Ask yourself: _"What business goal is this code trying to achieve? After the
   change, does it still achieve that goal — at **every** consumer, not just the
   one in the diff?"_

Anchor every "I checked all N usages" claim to an actual tool result, not to
memory. A consumer you skipped without declaring it is a bug in the review, not a
clean pass. Prioritize files at the center of the business flow; read as many
related files as the reference set demands.

## Verify & ground (do not skip when the stack allows it)

A review that only reasons about the diff is unverified. Before writing the
report, ground your correctness claims in real tool output:

1. **Run the project's non-mutating checks** — tests, typecheck, and lint,
   scoped to the changed files where possible. Detect the **package manager**
   (from the `packageManager` field / lockfile → pnpm | yarn | npm) **and the
   runner** (package.json scripts, Makefile, CLAUDE.md).
   **Prefer the underlying binary, scoped to the change** (`npx eslint <files>`,
   `npx tsc --noEmit`) over aggregate scripts — script _names_ vary per repo
   (one repo's typecheck script is `types`, another's `typecheck` or `tsc`),
   binaries do not. In a non-JS stack run the equivalent (`go test`, `pytest`,
   `cargo test`); ask permission if the command falls outside the allowed set.
2. **Only non-mutating commands.** Run tests / typecheck / lint — never a build
   that emits artifacts, codegen, or a formatter in `--write` mode. A review must
   not change the tree. **Aggregate scripts often hide these:** a repo's
   `typecheck` may run `codegen` first and `lint` may chain a `--write` formatter
   (e.g. `pnpm typecheck` → `codegen && …`, `pnpm lint` → `format:fix && …`).
   Read the script in package.json before running it; if it mutates, invoke the
   binary directly (`tsc --noEmit`, `eslint` without `--fix`).
3. **If you cannot run them** (sandbox, missing deps), say so explicitly in the
   report's **Scope & evidence** section and mark the affected findings
   **unverified** — do not imply you checked.
4. Anchor every "this works" / "tests pass" / "✅ looks good" claim to an actual
   result from this step, not to a reading of the code. If the diff adds a test,
   confirm it actually runs and passes.

## Evidence tiers — tag every finding with how you know

A finding is only as strong as the evidence behind it. Tag each one, and carry
the tag into the report's `Evidence` column:

| Tier       | What it means                                                                                            |
| ---------- | -------------------------------------------------------------------------------------------------------- |
| `OBSERVED` | You ran the real thing — the app in a real browser, the real runtime/CLI, an e2e run — and saw it happen |
| `TESTED`   | A test you actually executed passes/fails on exactly the point at issue                                  |
| `TRACED`   | Code reading and reasoning only — no execution                                                           |

`TRACED` is legitimate, full-strength evidence for **static-class** findings —
ones the source fully determines: wrong formula, null/off-by-one, broken caller
contract, injection, hardcoded secret, dead code, missing validation. Read the
code, trace a concrete input, report at whatever severity the impact warrants.

### Runtime-class findings: reading code does not settle them, and neither does a simulated environment

A separate class of claim depends on the **real runtime's ordering and state**,
which the source text does not contain:

- framework effect / batching / scheduler order — which render or commit lands first
- event-loop races: `await` continuation vs. a state update vs. a subscription callback
- browser history stack, routing, back/forward navigation, guards
- DOM / CSS / layout / focus / real event dispatch / hydration mismatch
- data-fetch order, cache/revalidation timing, loading and error states
- backend concurrency: locks, retries, transaction and message ordering

A headless simulation (jsdom, fake timers, a mocked router, an in-memory double,
`act()`-wrapped renders) is a **hypothesis, not proof**: its scheduling is an
artifact of the harness, not of production. A red test there is `TESTED`, but it
is still a simulated environment.

To reach `OBSERVED` on a runtime-class claim:

- run it in the real environment — the project's e2e (Playwright/Cypress) drives
  a real browser; a real server/CLI run drives the real event loop; **or**
- instrument the actual code path — put a log/breakpoint at each of the two
  points whose order is in dispute, run the real app, and read the order off the
  output.

## Review across dimensions

### Business Logic (most important dimension)

- **Establish intent from the project's own record first.** If the repo keeps
  business/architecture docs — feature docs, a domain glossary, ADRs, design
  docs, per-feature READMEs, wherever this repo happens to keep them (check the
  repo's `CLAUDE.md` / `README` / a `docs/` directory for what exists) — read
  the ones covering the touched features BEFORE judging intent, and treat an
  accepted ADR / verified feature doc as ground truth over your own inference.
  Commit messages and ticket refs supplement this, they don't replace it. No
  such docs → say so and state the intent assumption you're reviewing against.
- Does the change match the business intent? Does it violate any implicit rule
  (e.g. "an order can only be created when balance > 0")?
- Business edge cases: empty state, cancellation, refund, duplication, user
  permissions.
- Are contracts between modules broken? Are callers affected but left unfixed?
- Any unintended behavior change (regression)?
- **Scope check:** use the commit messages / ticket refs from `git log` to
  establish what the change was _meant_ to do, then flag any behavior change in
  code unrelated to that goal — an out-of-scope regression hides in the parts of
  the diff nobody was looking at.

### Security

SQL/NoSQL injection, XSS, CSRF, auth/authorization flaws, secrets in code, SSRF, path traversal, unsafe deserialization.

### Performance

N+1 queries, unbounded loops/queries, O(n²) complexity in hot paths, missing indexes, resource leaks, redundant allocations.

### Correctness

Null/empty/overflow, off-by-one, race conditions & concurrency, error handling & propagation, type safety.

- **Trace one concrete input.** Pick a real scenario (actual numbers/state) and
  follow it through the changed code path step by step — the value at each line,
  not a hand-wave. Most correctness bugs surface the moment you compute a real
  case instead of describing the logic.

### Maintainability

Naming, single responsibility, code duplication, test coverage, docs for non-obvious logic.

### Dependency changes (only when a manifest changed)

If the diff touches `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml`
etc. (lockfiles stay excluded), review each **added or major-bumped** dependency:

- **Necessity** — does the codebase (or an already-present dependency) cover
  this? A one-function util rarely justifies a new package.
- **Health & provenance** — maintained, widely used, from the expected publisher
  (no typosquat)? License compatible with the project?
- **Weight** — for frontend deps, bundle-size impact; is a lighter/tree-shakeable
  alternative available?
- **Version pinning** — does the range style match the repo's convention?

Removed deps: grep for leftover imports. Version bumps: note known breaking
changes if the major changed.

### Conditional review criteria — apply only when the diff trips the trigger

The dimensions above are always-on; these checklists activate only for diffs
that match their trigger. Check the trigger, then apply or skip silently —
never pad a report with "N/A" sections.

#### Test quality (trigger: the diff adds/modifies tests, or changes logic that existing tests cover)

Updated tests are necessary but not sufficient — judge whether they *prove*
anything:

- **Real assertions.** Do the tests pin concrete expected values, or only
  snapshots / "renders without crashing" / "does not throw"? A snapshot-only
  test locks in whatever the code does, including the bug.
- **The subject is actually exercised.** A test that mocks away the very unit it
  claims to test proves nothing — check what's mocked vs. what's asserted.
- **Bug fixes need a prove-it test**: one that fails on the old code and passes
  on the new. If the fix has no test that would have caught the original bug,
  say so.
- **Edge cases the change introduces** (empty, null, boundary, error path) —
  covered, or happy-path only?

#### Accessibility & i18n (trigger: the diff touches UI markup, components, or styles)

- Interactive elements are keyboard-reachable and have an accessible name
  (label, `aria-label`, or text content); focus states aren't suppressed;
  meaning isn't conveyed by color alone; new images/icons carry text
  alternatives; new page/section structure uses sensible headings/landmarks.
- User-facing strings go through the project's i18n mechanism **if one exists**
  (grep for how neighboring components emit text) — no hardcoded literals in a
  codebase that localizes; dates/numbers formatted via the project's locale
  utilities, not `toString`. A project with no i18n layer → skip, don't invent
  the requirement.

## Disprove each finding before you report it (mandatory)

Finding issues and judging them are different modes — after the sweep above,
switch sides: for EVERY candidate finding, actively try to **kill it** before it
reaches the report.

- **Re-read the exact cited lines.** Is the claim about the code that is
  actually there, or about a paraphrase you built up while sweeping?
- **Hunt for the mitigation** you'd have missed: a later gate, validation,
  default, caller-side check, error boundary, or an existing test that makes
  the worst case unreachable. Found one → downgrade honestly and name it.
- **Recompute the concrete trace.** Run the real input through the code path
  once more — do the values still come out wrong?
- **Check the other layers**: is it already handled on the target side (drift
  step), in an untouched sibling, or is it pre-existing on `<REF>` rather than
  introduced by this branch? (Pre-existing issues may still be worth a note —
  but labelled as pre-existing, never as a regression of this branch.)

A finding that survives goes in the report. One that dies is dropped —
**silently**; don't pad the report with disproved candidates. One you can
neither confirm nor kill goes in at its evidence-capped severity with the exact
steps the user can run to settle it.

## Classify severity

Each issue MUST be assigned exactly one of 4 levels:

- **CRITICAL** — Absolute merge blocker. Immediate serious impact: exploitable security hole (injection, leaked secret, auth bypass), data loss/corruption, broken core business logic (wrong billing, wrong stock deduction), production crash, broken contract that breaks callers.
- **HIGH** — Should fix before merge. Clear correctness bug but narrower scope: race condition, unhandled business edge case (order cancellation, refund, duplication), missing important input validation, N+1 / performance issue in a hot path, faulty error handling that swallows exceptions.
- **MEDIUM** — Should fix, not a merge blocker. Affects quality/maintainability: missing tests for important logic, code duplication, high complexity that is hard to read, misleading naming, performance issue outside hot paths.
- **LOW** — Nice-to-have. Style, minor naming, missing comments, micro-optimizations, non-urgent refactor suggestions.

Three rules decide the final level, in this order:

1. **Evidence caps severity.** For a **runtime-class** finding (see the evidence
   tiers above), `TRACED` and simulated-environment `TESTED` both cap at
   **MEDIUM**. Only `OBSERVED` unlocks HIGH/CRITICAL. **Static-class findings
   are not capped** — `TRACED` is full strength for them.
   If you cannot reach `OBSERVED` and you believe the issue is serious, **do not
   promote it** — report it at its capped level and give the user the exact steps
   to settle it. One question costs far less than a confident wrong finding they
   act on; being wrong twice about the same finding destroys their trust in the
   whole review.
   Self-check before any HIGH/CRITICAL: _"Could this result be an artifact of the
   environment I ran it in?"_ The tell is a sibling test that passes **only**
   because of ordering — that means the harness, not the code, decided your
   outcome.
2. **Severity realism — trace impact before you finalize.** A finding's severity
   is its _real-world_ worst case, not its worst case in isolation. Is there a
   later gate, validation, or compensating control that catches it? If the worst
   case genuinely cannot occur, **downgrade honestly and name the mitigation** in
   the finding. Inflating a mitigated issue erodes trust just as much as missing
   one.
3. **When genuinely torn between two levels → pick the higher one and state why.**
   This tie-break applies only to impact you _have evidence for_. It never
   overrides rule 1 — it is not a way to launder a guess into a HIGH.

## Produce the report

**Report language.** The report is conversational output, so write its prose —
the Overview, the Business Logic narrative, each issue's description and fix
rationale, "What looks good", the verdict reason — in the language the user is
conversing in (or the language configured in their Claude settings). Do not
default to English just because this file is written in English.

Two things stay in English regardless of the report language, so the report stays
greppable and consistent with the codebase:

- **Structural labels and keywords**: the section headings of the template below,
  the severity levels (CRITICAL / HIGH / MEDIUM / LOW), the categories (Business /
  Security / Performance / Correctness / Maintainability), the evidence tiers
  (OBSERVED / TESTED / TRACED), and the verdict (Approve / Request changes /
  Needs discussion).
- **Anything quoted from or destined for the codebase**: `file:line` refs, symbol
  names, sample fix code and its comments, route/commit/branch names, and any text
  the user asks you to persist (an exported file, an MR comment) — those follow
  the repo's English-artifact rule, not the conversation language.

Then follow this template:

```markdown
## Code Review: <current branch> → <REF>

### Overview

<1-3 sentences: what the diff does, overall quality, whether it should merge>

### Scope & evidence

- **Compared against:** <the ref you diffed against — `origin/<TARGET>` or a
  local fallback — and whether TARGET was user-supplied or auto-detected; note
  if the fetch failed and the ref may be stale>
- **Reviewed:** <what you actually read — file count / list; any uncommitted or
  untracked files folded in (or skipped); the target-side drift check's result;
  under the wide-blast exception: which parts were read fully vs sampled, with
  the real numbers>
- **Ran:** <the non-mutating checks you actually executed, and their result — or
  "could not run: <reason>", in which case say which findings are unverified>

### Summary

| Severity    | Count |
| ----------- | ----- |
| 🔴 CRITICAL | x     |
| 🟠 HIGH     | x     |
| 🟡 MEDIUM   | x     |
| 🔵 LOW      | x     |

### 🧠 Business Logic

<The most important section. State the business intent you understood, whether
the change achieves it, and any regression / broken-contract / cross-variant
divergence risk.>

### Issues

List in order CRITICAL → HIGH → MEDIUM → LOW.

| #   | Severity | Evidence | File:Line | Category | Issue | Fix |
| --- | -------- | -------- | --------- | -------- | ----- | --- |

<Severity: CRITICAL / HIGH / MEDIUM / LOW>
<Evidence: OBSERVED / TESTED / TRACED>
<Category: Business / Security / Performance / Correctness / Maintainability>

Any runtime-class finding at HIGH or CRITICAL must show `OBSERVED`; otherwise it
is capped at MEDIUM and the report must name the exact steps the user can run to
settle it.

For each CRITICAL and HIGH issue, add a short explanation below the table:
why it is wrong + sample fix code (if helpful).

### ✅ What looks good

- <Positive observations>

### Verdict

**Approve** / **Request changes** / **Needs discussion**

- Any CRITICAL → must be **Request changes**.
- Any HIGH → default to **Request changes**; a genuinely debatable HIGH may
  be **Needs discussion** — say why.
- Only MEDIUM/LOW left → may **Approve** with notes.
  Include a short reason.
```

## Principles

- Cite specific `file:line`, no vague statements.
- Each issue includes: why it is wrong + how to fix (sample code if helpful).
- If unsure about the business intent, state the assumption you are using instead
  of guessing.
- Be honest: if the code is good, say so; don't invent problems.
- **Ground before you praise.** Anything in "✅ What looks good" or any "this is
  correct" claim must trace to a tool result (a passing test, a clean typecheck)
  or an explicit code trace — not a vibe. If you could not verify, say so.
- **Never launder a guess into a severity.** State how you know before you state
  how bad it is; if the evidence tier does not support the level, lower the level
  — do not upgrade the confidence.
