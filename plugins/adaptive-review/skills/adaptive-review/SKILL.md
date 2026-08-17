---
name: adaptive-review
description: >
  Review the current git branch's diff against a target branch in one of two
  modes. MINIMAL walks the changed code against bundled markdown checklists
  only (git + Read, no agents, no MCP tools) — fast, cheap, portable. ADVANCED
  adds blast-radius mapping with codegraph/serena, independent reviewer and
  verifier agents, the repo's settled-decision record, and browser observation
  of runtime-class findings with agent-browser. Frontend-first (React,
  TypeScript, Next.js) with a stack-agnostic core; extensible by dropping a
  checklist file, and per-repo criteria plug in via `.claude/review-skills.md`.
  Use this whenever the user asks for a code review, branch review, pre-merge
  review, PR/MR self-review, "review my changes", "check this diff", "quick
  review" / "deep review", or wants findings on React/TypeScript changes — even
  if they never say "review". Read-only git; never edits code.
argument-hint: "[minimal|advanced] [<target-branch>] — e.g. `advanced develop`, `minimal`, or empty to auto-pick both"
license: MIT
metadata:
  version: "1.0.0"
---

# adaptive-review

Review the work on the **current branch** relative to a **target branch**, in
the depth the situation calls for. Two modes share one spine (scope → intent →
criteria → review → disprove → report) and one report format; they differ in
*how much evidence* they gather before a finding is allowed to exist.

| | **Minimal** | **Advanced** |
| --- | --- | --- |
| Reads | the diff + full changed files + bundled checklists | the same, **plus** every consumer the blast radius turns up |
| Tools | `git` (read-only), `Read`, `Grep`/`Glob` | + `codegraph` / `serena` (fallback `rg`), `Agent`, `agent-browser` |
| Who reviews | you, one pass per checklist bucket | independent reviewer agents per persona, then verifier agents that try to refute |
| Evidence ceiling | `TRACED` | `OBSERVED` — runtime-class findings get reproduced in the real app |
| Best for | small/medium diffs, quick pre-push check, hosts without MCP/agents | risky or wide diffs, shared symbols, UI behaviour that must be seen |

Everything below is **read-only**: `git diff/log/show/status/branch/rev-parse/
fetch` only — never `checkout`, `commit`, `reset`, `push`, `stash`, and never a
build, codegen, or a formatter in write mode.

## Files in this skill — load on demand, not up front

| File | Load when |
| --- | --- |
| `references/scope.md` | Step 1 — resolving the target and collecting the diff |
| `references/project-addendum.md` | Step 3 — reading `.claude/review-skills.md` (and how a repo writes one) |
| `checklists/index.md` | Step 3 — mapping changed files → checklist files |
| `references/mode-minimal.md` | Step 4, minimal mode |
| `references/mode-advanced.md` | Step 4, advanced mode (it points at `references/personas.md`) |
| `references/standards.md` | Step 5 — evidence tiers, severity, disprove pass, report template, verdict |

Read each at the step that needs it. Loading them all at once carries their
weight through every later turn and (in advanced mode) into every agent brief.

## Step 0 — Parse the invocation and pick the mode

Tokens may arrive in any order: a mode word (`minimal` / `advanced`, also
accept `quick`/`light`/`fast` → minimal and `deep`/`thorough`/`full` →
advanced) and an optional target branch. Anything else → treat it as the
target branch name and confirm it in Step 1.

If no mode token was given, **pick one and say so** rather than asking —
the user can rerun with the other word, and the announcement makes the trade
clear:

- **Advanced** when the host exposes the `Agent` tool **and** at least one of
  `codegraph_*` / `serena` (`find_referencing_symbols`) tools, and the diff
  touches source files. Those are exactly the capabilities advanced mode
  spends; with them present, the deeper review is what the user set the
  machine up for. (A tool is "exposed" when it is in your function list or a
  single tool search by name returns it; otherwise treat it as absent — do not
  keep probing.)
- **Minimal** otherwise — including any host where agents or MCP tools are
  absent, or when the diff is docs/config-only.
- The repo addendum (Step 3) may declare a `Default mode`; when it does, that
  wins over this heuristic (a team that knows its risk profile has decided).

Announce in one line: `Mode: advanced (auto — codegraph + Agent available; pass
"minimal" for a checklist-only pass)`. Never silently downgrade: if advanced
was requested but a capability is missing, run advanced's *shape*
sequentially (see `mode-advanced.md` → Degraded mode) and say which
capability was missing.

## Step 1 — Scope: resolve the target and collect the diff

Read `references/scope.md` and follow it. It owns: default-branch detection
(never assume `main`), preferring `origin/<target>` over a stale local ref,
the dirty-tree and untracked-file rules, rename detection, the large-diff
guard, target-side drift, and stacked-branch detection. Its output is `<REF>`,
the changed-file list, the diff, and the notes that go into **Scope &
evidence**.

## Step 2 — Establish intent before judging anything

A finding only makes sense relative to what the author was trying to do.
Gather, in this order, and write a 2–3 line intent summary you will review
against (and, in advanced mode, hand to every agent verbatim):

1. Commit messages on the branch (`git log <REF>..HEAD` with bodies) and any
   ticket refs they carry.
2. The PR/MR title and description if one exists (`gh pr view` / `glab mr
   view` when available — read-only).
3. The repo's own record for the touched area: feature docs, ADRs, a domain
   glossary, plan files — wherever this repo keeps them (`CLAUDE.md`,
   `README`, `docs/`). An accepted record is ground truth over inference.
4. Only then, the diff itself.

No usable record → say so and state the intent assumption you are reviewing
against. Do not stop to ask.

## Step 3 — Select criteria: repo addendum + checklists + tech-stack skills

Three sources, layered; the more specific wins on criteria, never on the
severity scale or report format:

1. **The repo's addendum — `.claude/review-skills.md`.** Check whether it
   exists (`ls .claude/review-skills.md`); absent → skip silently and do not
   load the contract. Present → read `references/project-addendum.md` for its
   contract, then `Read` the file. It is binding: mandatory skills,
   repo-specific intent sources, defect classes known to bite here, things
   *not* to flag, an optional default mode, and optional non-mutating checks
   the repo wants run in advanced mode.
2. **Bundled checklists — `checklists/index.md`.** Read the index and load
   only the rows whose triggers match a changed file (all `Always` rows plus
   the matching stack rows). The index is the single source of truth; do not
   hard-code checklist names here.
3. **Tech-stack skills already installed on the host — optional.** The bundled
   checklists are complete on their own; this step only *adds* whatever the
   host happens to have (e.g. a React Compiler skill, a `useEffectEvent`
   skill, a project's Next.js skill). None found → skip silently. Match by the
   skill's declared stack/description, not its name; when unsure, read its
   `SKILL.md`. A skill counts as matched **only when a changed hunk falls in
   its scope** (a `useEffect` in the diff for `react-effect-event`; a
   component or hook for `react-compiler`) — loading one costs context, so a
   skill whose scope the diff never touches is not loaded. *Who loads it
   depends on the mode:* in **minimal** you invoke it with the `Skill` tool
   yourself; in **advanced** you do not load it — you name it in the owning
   persona's brief and that agent invokes `Skill(<name>)` itself, so its rules
   sit in the reviewer's context, not in yours and every other brief. Each
   loaded skill is an extra criterion for the files in its scope; findings
   from it are attributed to it by name; a loaded skill that yields nothing is
   listed in Criteria as "yielded nothing". Do not scan the filesystem for
   `SKILL.md` files — use the harness's skill list.

Tell the user in one line what you selected, marking addendum-required items:
`Criteria: core (5 always + tests) + frontend/react, frontend/typescript,
frontend/ui-a11y-i18n + react-compiler (installed skill) + repo addendum
(2 defect classes)`.

## Step 4 — Run the mode

- **Minimal** → read `references/mode-minimal.md`. One careful pass per
  checklist bucket, full files not hunks, a concrete input traced through each
  non-trivial change, then the disprove pass. No agents, no graph tools, no
  browser — that is the point of the mode, not a limitation to work around.
- **Advanced** → read `references/mode-advanced.md`. Blast radius first (graph
  tools, every consumer opened), settled-decision check in both directions,
  reviewer agents fanned out per persona with fresh context, verifier agents
  fanned in to refute, and runtime-class candidates taken to the running app
  with `agent-browser` before they may carry HIGH/CRITICAL.

Both modes obey the same **confidence control**:

- Report only what you are **>80% confident** is real; leave the rest out.
  Padding erodes trust faster than a missed nit.
- Review **only what this branch changed**. Pre-existing issues stay out —
  except a CRITICAL security hole in the surrounding code, which is reported
  and labelled pre-existing.
- Do not flag: pure style, anything a linter/typechecker/formatter already
  catches, a rule the code deliberately silences with a stated reason,
  behaviour changes that are clearly the point of the change, or a
  "duplicated"/"inconsistent" pattern that the repo's record already explains
  as deliberate.
- **Quote the line.** Before a finding may be HIGH/CRITICAL, cite the verbatim
  `file:line` that makes it true — this kills the "that field doesn't exist"
  false-positive class.

## Step 5 — Disprove, classify, report

Read `references/standards.md` and apply it as written: switch sides and try
to kill every candidate (re-read the cited lines, hunt for the mitigation,
recompute the trace, check the target side and the record); tag each survivor
with an evidence tier (`OBSERVED` / `TESTED` / `TRACED`); let evidence cap
severity for runtime-class findings; then render the report template with the
title `## Adaptive Review (<mode>): <branch> → <REF>` and end with the verdict.

Report prose is written in the user's conversation language; structural
labels, severities, evidence tiers, verdict words, and anything quoted from or
destined for the codebase stay in English.

## Extending this skill

- **A new stack** (backend, mobile, …): add `checklists/<stack>/<topic>.md`
  and one row per file in `checklists/index.md`. Nothing else changes — the
  spine reads the index. Advanced mode picks up new personas the same way:
  add a section to `references/personas.md` and reference the checklist.
- **A new cross-cutting concern** (e.g. observability): add a `core/` checklist
  with an `Always` or path trigger.
- **A specific repo**: never edit this skill — write `.claude/review-skills.md`
  in that repo (`references/project-addendum.md` has the template and the
  bar for what belongs there), or let the bundled
  `/adaptive-review:init-review-addendum` command generate one from the
  repo's own history.

Everything the review needs ships in this plugin. The only external pieces
are **optional tools** the host may or may not expose — codegraph, serena,
`Agent`, agent-browser, `gh`/`glab` — and **optional installed skills** picked
up at Step 3; absence of any of them narrows the evidence, never blocks the
review.
