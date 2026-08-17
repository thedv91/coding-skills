---
description: Survey the current repo and generate (or refresh) its .claude/review-skills.md — the repo-specific criteria file that adaptive-review loads at Step 3.
argument-hint: "(none) — optionally 'refresh' to rebuild an existing addendum from scratch"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion
---

# Bootstrap this repo's review addendum

Produce **`.claude/review-skills.md`** in the current repo root. The
`adaptive-review` skill reads it at Step 3 and treats it as **binding
criteria** — so everything you write must be earned from evidence in this
repo, not from generic best-practice knowledge the bundled checklists already
carry. The file's contract and template live in the skill's
`references/project-addendum.md`; read that file first.

`$ARGUMENTS` may contain `refresh` — see Phase 0.

**The bar for every line:** would a competent reviewer who knows the language
but not *this* repo get it wrong without being told? Yes → it belongs. No →
leave it out. A bloated addendum is worse than none.

## Phase 0 — Does an addendum already exist?

```
ls .claude/review-skills.md
```

- **Absent** → build it (continue).
- **Present, no `refresh`** → `Read` it, run Phases 1–3, and report only the
  **delta**: skills now available that aren't listed, listed skills that no
  longer exist, criteria contradicted by current code, defect classes recent
  history shows that the file misses. Ask via `AskUserQuestion` whether to
  apply the delta; apply only what the user accepts. **Never silently
  overwrite a file a human curated.**
- **Present, `refresh`** → still `Read` it first and preserve any hand-written
  rule you cannot re-derive; say which ones you carried over.

Not in a git repo → say so and STOP (this command reasons from repo history).

## Phase 1 — Learn the repo from evidence

Run these; skip what does not apply. Every claim in the output must trace to
something you observed here.

1. **Stack & tooling** — the manifest that exists (`package.json`,
   `pyproject.toml`, `go.mod`, …): framework + major version, test runner,
   lint/format tooling, the scripts a reviewer would tell someone to run.
2. **CI?** — `ls .github/workflows .gitlab-ci.yml .circleci 2>/dev/null`. No
   CI is a review-relevant fact; CI that already enforces lint/types means the
   review must NOT re-flag what it catches.
3. **The repo's own rules** — `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`,
   `README`, `.cursor/rules/`, `docs/`. Note what they mandate but **do not
   copy them** into the addendum — reference the file; two copies drift.
4. **Intent sources** — ticket-key convention (`git log --oneline -40`,
   `git branch -a` → `ABC-1234` patterns), a domain glossary, ADR directory,
   per-feature docs.
5. **Sibling/legacy code worth parity checks** — only with real evidence (a
   monorepo sibling package, a documented predecessor implementation). Do
   not invent one.
6. **How the app is launched and checked** — dev command, port, how to get an
   authenticated session (for advanced mode's browser observation), and which
   test/typecheck/lint commands are **non-mutating** (read the scripts: a
   `lint` that chains `format --write` or a `typecheck` that runs codegen is
   not eligible for *Checks to run*).

## Phase 2 — Pick skills from the harness list only

The harness lists every available skill in your context. **Do not scan the
filesystem for `SKILL.md`.** Select against Phase 1:

- **always** — relevant to essentially *every* diff here. **Cap at 3.**
- **conditional** — a skill plus the concrete diff trigger that fires it ("the
  diff adds a `useEffect`"). A trigger a reviewer cannot evaluate from the
  diff is not a trigger.

Never list a skill not in the available list; never list one whose whole
value the bundled checklists already cover; never list a skill that *writes*
code without stating it is applied as a read-only criterion.

## Phase 3 — Mine the repo's own defect history

This is what makes the addendum worth more than a generic checklist:

```
git log --oneline -60 --grep='fix\|bug\|hotfix\|revert' -i
```

Read a handful of the most substantive fixes (`git show --stat <sha>`, then
the interesting file's diff). Look for **classes**, not incidents: a contract
everyone forgets, a value that must be propagated to several sites, a
provider that throws when consumed out of scope, a unit/rounding convention,
an enum assumed exhaustive. Three or four real ones beat twelve guesses. Also
note what reviewers should **not** flag (a documented deliberate deviation, a
lint rule intentionally off). Found nothing convincing → write nothing there
and say so.

## Phase 4 — Confirm before writing

Present in chat: the proposed **always** list (one-line justification each),
the conditional triggers, the defect classes with the commit each came from,
the proposed default mode, and the checks you judged non-mutating. Then
`AskUserQuestion`: `Write it as proposed` / `Let me trim the list` (go item by
item) / `Cancel`. Nothing is written without an explicit choice.

## Phase 5 — Write `.claude/review-skills.md`

Use the template in `references/project-addendum.md`, in English, omitting
sections with nothing earned. Format it with the repo's own formatter **only
if the repo formats markdown**.

## Phase 6 — Wire it up, then report

Offer (do not do unasked) a one-line pointer in the repo's `CLAUDE.md`: the
addendum's path, and that new review rules go **there**. Report: the path
written, always/conditional counts, defect classes and their commits, and —
honestly — what you could not determine and left out.

## Guardrails

- **Evidence or silence.** No criterion you did not observe in this repo.
- **No duplication.** If `CLAUDE.md` or the bundled checklists already say
  it, reference it; do not restate it.
- **Criteria, not process.** The severity scale, evidence tiers, and report
  format stay owned by the skill. Never write a competing report template.
- **Never overwrite a curated file** without the Phase 0 delta + confirmation.
