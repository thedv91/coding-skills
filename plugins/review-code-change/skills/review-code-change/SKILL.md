---
name: review-code-change
description: >
  Review the diff of the current git branch against a target branch the user
  provides, checking only the changed code against a set of standards. Trigger
  this skill on requests like "code review", "review diff", "review against
  target branch", "review my branch before merge", or "pre-merge review". Each
  standard lives in its own file under references/ so the rule set can be
  extended without editing this file. Read-only git only.
license: MIT
metadata:
  version: "1.0.0"
---

# review-code-change

Review the work introduced on the **current branch** relative to a **target
branch**, judging only the changed lines against a set of standards. Standards
are stored one-per-file under `references/`; `references/index.md` is the single
source of truth that maps file types/paths to the standards that apply.

## When to apply

Apply when the user wants a review of the current branch's changes versus a
target branch — e.g. before opening or merging a pull request. Do **not** apply
when the user wants a full-repo audit, a review of a single file in isolation,
or a review of code that is not part of this branch's diff.

## Workflow

1. **Resolve the target branch.** Use what the user gave (e.g. `main`,
   `develop`, `origin/main`). If none was given, detect the repo's default
   branch rather than assuming `main` — many repos merge into `dev`, `develop`,
   or `master`:

   ```
   git rev-parse --abbrev-ref origin/HEAD   # e.g. "origin/dev" → target = dev
   ```

   If `origin/HEAD` is unset, fall back to
   `git branch -rl origin/main origin/master origin/dev origin/develop` (prefer
   in that order; list the patterns separately — git does not expand `{a,b}`
   braces, so one quoted brace pattern silently matches nothing). Ask the user
   only when detection yields nothing or more than one plausible answer. Record
   in the report whether the target was user-supplied or auto-detected.

2. **Compute the changed set via merge-base** so only this branch's own work is
   reviewed (commits the target made after the branch point are excluded):
   - File list: `git diff --merge-base <target> --name-only`
   - Hunks: `git diff --merge-base <target>`

   Everything this review runs — git, and the graph tools below — is read-only
   inspection, in the orchestrator and in every agent alike. Never `commit`,
   `checkout`, `reset`, `push`, or otherwise mutate the repository.

3. **Understand the intent first.** Before judging anything, establish what the
   change is for: read the branch's commit messages
   (`git log <target>..HEAD --oneline` and message bodies) and the
   PR title/description if one exists. A finding only makes sense relative to
   what the author was trying to do.

4. **Select which standards apply (progressive disclosure).** Read
   `references/index.md` and use its mapping to decide which reference files to
   load. Load **only** the relevant ones — never the whole set.
   - Load every standard whose **Triggers** column is `Always`.
   - Add each standard whose trigger matches a changed file's type/path.

   `index.md` is the authoritative list — do not hard-code standard names here.
   If a changed file maps to no language standard, the `Always` standards still
   apply.

   **Also discover the project's own tech-stack skills.** The bundled
   `references/` are not the only standards. A project commonly installs
   best-practice skills for its own framework, platform, or house style. These
   are project-dependent, so they live nowhere in `index.md` — discover them at
   review time from the skills the harness already lists in context. Match a
   skill to the diff by its declared **stack/description, not its name**; when
   unsure whether one applies, read its `SKILL.md` before deciding. Treat each matching
   skill as an **additional standard** for the corresponding language bucket, and
   load its guidance only when a changed file falls in its scope — the same
   progressive-disclosure rule as the bundled references.

5. **Read surrounding code and trace impact across the codebase.** Each reviewer
   agent does this within its own bucket (see _Independent multi-agent review_).
   For each non-trivial hunk, open the full file before judging. Never evaluate a
   hunk in isolation — a line that looks wrong in the diff may be correct in context, and
   vice versa. And never judge a changed symbol in isolation either: before
   forming any finding about a changed **function, method, exported variable,
   type, or constant**, map who depends on it. A one-line change to a shared
   symbol can break callers the diff never shows.
   - **Use graph/semantic tools, not text `grep`**, so renames, overloads, and
     re-exports are caught rather than missed.
     - **codegraph** (primary, when the project has run `codegraph init` — check
       with `codegraph_status`): `codegraph_impact <symbol>` for the repo-wide
       blast radius, `codegraph_explore` for the verbatim source of affected
       sites plus the call paths between them, and `codegraph_callers` /
       `codegraph_callees` for direct edges.
     - **Serena** (fallback when codegraph is not initialized):
       `find_referencing_symbols`, `find_symbol`, `get_symbols_overview`,
       `find_implementations`, `find_declaration`.
   - **For each dependent site, ask whether the change alters the symbol's
     contract** — signature, return type, thrown errors, null/empty behavior,
     ordering, or side effects — and whether every caller still satisfies the new
     contract. For a **renamed or removed** symbol, confirm every reference was
     updated.
   - **If callers cannot be fully traced** — dynamic dispatch, reflection,
     string-keyed lookup, cross-package boundaries — **say so and lower that
     finding's confidence** accordingly.

6. **Put every candidate finding through refutation before it is reported** —
   see _Independent multi-agent review_ for how, and _Confidence control_ for the
   bar it has to clear. A false positive costs more trust than a missed nit.

7. **Report findings grouped by standard**, in the output format below — the
   orchestrator merges the verified findings from every agent into one report.

## Independent multi-agent review

A single pass that both raises a finding and clears it is the weakest link: the
same context that produced the finding rationalizes it. So no agent here ever
sees another's reasoning — that separation is the whole mechanism, and everything
below exists to preserve it.

- **Orchestrator (you).** Resolve the target, compute the diff, read the intent,
  select the standards — once — then package a brief every agent receives
  verbatim: target branch, diff, changed-file list, a one-paragraph intent
  summary, the selected reference files, and any project-installed stack skills
  you matched. The orchestrator does not review: it dispatches, deduplicates, and
  renders the final report.

- **Reviewer agents — fan out to find.** One agent per **standard bucket**, each
  holding only its brief and its own reference file(s). Each opens the full files
  and traces cross-codebase impact within its remit, then returns candidates in
  the output format. Default buckets (drop any whose standards weren't selected;
  split a large one, merge tiny ones):
  - **Security** — `security.md`.
  - **Correctness & intent** — `business-logic.md`, `user-perspective.md`.
  - **Code health** — `code-quality.md`, `performance.md`, `best-practices.md`.
  - **Language** — the triggered subset of `typescript.md`, `react.md`,
    `nextjs.md`, `nodejs.md`, **plus any project-installed stack skills you
    matched**. The language agent checks the changed code against both, and
    attributes each finding to the source it came from so the report shows which
    standard was violated.

  If the host exposes specialist agent types, route a bucket to the matching one
  (security → a security auditor); otherwise a general reviewer agent is fine.

- **Verifier agents — fan in to refute.** After deduplicating candidates by
  (file, line, claim), hand each survivor to a **different** agent than the one
  that raised it, tasked to _refute_ it: point to the exact line and prove it
  wrong, or trace an input that breaks it. Keep only what survives and clears the
  >80% bar.

**Degraded mode.** Where the host cannot spawn subagents, run the same shape
sequentially — one bucket at a time as a self-contained pass, then re-examine
each candidate adversarially before it ships. The separation is weaker this way,
so hold the >80% bar more strictly to compensate.

## Confidence control

Aim for **high signal**: a short list of real, substantiated issues beats a long
list padded with maybes.

- Report only findings you are **>80% confident are real**. When unsure, leave
  it out rather than padding the report.
- **Skip pure style nits** (formatting, subjective naming preferences) unless a
  standard explicitly flags them.
- **Skip pre-existing issues in unchanged code** — review only what this branch
  changed. The one exception: a **CRITICAL security** issue you can see in the
  surrounding code; surface it, labeled as pre-existing.
- Do not invent weaknesses to fill a quota. If a standard has no findings, say so.

**Do NOT flag (false positives that erode trust):**

- Pre-existing issues outside the diff (except the CRITICAL-security exception).
- Code that _looks_ like a bug but is actually correct in context — verify
  before reporting.
- Pedantic nitpicks a senior engineer would not raise.
- Anything a linter/formatter/type-checker already catches.
- Issues that only manifest under specific inputs/state you cannot show actually
  occur.
- A rule that the code explicitly and deliberately silences (e.g. an
  `eslint-disable` with a stated reason).

## Output format

Group findings under a heading per standard (e.g. `## Security`). A matched
tech-stack skill counts as a standard for this purpose — name its heading after
the skill (e.g. `## react-compiler`). For each finding:

```
[SEVERITY] Short title
File: path/to/file.ext:line
Issue: What is wrong and why it matters, in one or two sentences.
Fix:   The concrete change that resolves it.
```

Severity labels: **CRITICAL**, **HIGH**, **MEDIUM**, **LOW**. Each standard
file declares its default severity tier; an individual finding may be raised or
lowered from that tier when the specific case warrants it.

## Verdict rules

End the review with one verdict, derived from the highest severity present:

- **APPROVE** — no CRITICAL and no HIGH findings.
- **WARNING** — one or more HIGH findings, but no CRITICAL.
- **BLOCK** — any CRITICAL finding.

Guiding principle: approve a change when it clearly improves the codebase's
overall health, even if it is not perfect — MEDIUM/LOW findings are advice, not
gates. Reserve WARNING/BLOCK for issues that genuinely should not merge as-is.
It is fine to call out notably good work (a clean refactor, a well-placed test)
alongside the findings; praise is informational and never changes the verdict.

Then print a summary count table:

| Severity | Count |
| -------- | ----- |
| CRITICAL | n     |
| HIGH     | n     |
| MEDIUM   | n     |
| LOW      | n     |

## Extending this skill

Adding a new standard is two steps and requires **no edit to this file**:

1. Drop a new `references/<name>.md` file (severity-tagged title, rules as
   scannable bullets, BAD/GOOD snippets where useful).
2. Add one row to `references/index.md` describing the file, its severity tier,
   the file types/paths that trigger it, and a one-line scope.

The file-type → reference mapping lives **only** in `references/index.md`, so it
stays the single source of truth: the workflow reads that table, and never
hard-codes the list of standards.

That covers standards **bundled** with the skill. A project's own installed stack
skills vary per project, so they are never registered here — the review discovers
them at review time instead.
