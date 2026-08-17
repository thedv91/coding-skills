# Advanced mode — blast radius, independent agents, and the real app

Advanced mode exists for the findings a single reading cannot produce: the
consumer nobody opened, the decision the team already closed, and the UI
behaviour that only shows up when the page actually runs. It spends tools to
buy evidence. Every agent and tool here is still a **read-only inspector**.

Inputs from the spine: `<REF>`, diff, changed-file list, intent summary,
selected checklists, matched installed skills, repo addendum.

## 0. Take stock of the capabilities you actually have

Look at the tool list the harness gave you — do not probe blindly:

| Capability | Look for | Used for |
| --- | --- | --- |
| Code graph | `codegraph_explore` / `codegraph_impact` / `codegraph_callers` (and a `.codegraph/` dir in the repo, or `codegraph_status`) | blast radius, verbatim consumer source, call paths |
| LSP | `find_referencing_symbols`, `find_symbol`, `get_symbols_overview` (serena) | precise references, the authoritative "where is this used" |
| Agents | `Agent` tool | reviewer fan-out, verifier fan-in |
| Browser | `agent_browser_*` tools or the `agent-browser` skill; else the built-in browser tools; else Playwright in the repo | observing runtime-class findings |
| Forge CLI | `gh` / `glab` (read-only) | PR description, previous review threads |

Note what is missing; it goes into Scope & evidence, and it decides the
degraded shape at the end of this file. Codegraph is stale for ~2s after a
write and its `callers` list is measured incomplete (~94% vs the LSP) — treat
it as the fast overview and serena as the deciding reference list; when only
one exists, use it and say so.

## 1. Map the blast radius — before judging any line

For **each** changed symbol — exported function, hook, component, prop, type,
constant, derived value — enumerate its references **with a tool, not from
memory**:

1. **Graph first.** `codegraph_explore "<changed symbols / file names>"` — read
   its *Blast radius — what depends on these* section and the verbatim source
   it prints (treat that as read). `codegraph_callers <symbol>` for direct
   edges. Pass `file`/`projectPath` when a name could exist more than once —
   a bare homonym merges every definition into one answer.
2. **LSP to decide.** `find_referencing_symbols` (name_path + relative_path)
   for the reference list you will actually rely on.
3. **Fallback:** `rg -n '<name>' <src>` via Bash for every changed identifier
   when neither tool exists. Never assume the count; list the files.
4. **Open EVERY site the query returns.** Three files → read three. When two
   surfaces do the same job (desktop ↔ mobile, sibling switch branches, inline
   ↔ tooltip/detail variant), diff them against each other.
   **Wide-blast exception:** past ~20 references, group by surface (route,
   platform, sibling variant), read one representative per group plus every
   site adjacent to the change, and state the real coverage in Scope &
   evidence ("read 8 of 41 references, one per surface group").

Then, for each significantly changed file, read the whole file and check:
callers of the changed API (contract still satisfied — signature, return,
thrown errors, null/empty behaviour, ordering, side effects?), related
types/schemas (how does the data flow?), corresponding tests (updated?),
config / business-rule files. For a **renamed or removed** symbol confirm every
reference moved. If callers cannot be fully traced (dynamic dispatch,
string-keyed lookup, cross-package boundary) — say so and lower confidence.

Anchor every "I checked all N usages" to a tool result. A consumer skipped
without being declared is a bug in the review.

## 2. Check the settled decisions — in both directions

The diff cannot tell you what the team already decided. Gather the record:

1. **The repo's decision records** — ADR directory, `decisions/`, design docs,
   per-feature docs with a status field (the repo's `CLAUDE.md`/`README`/
   `docs/` say what exists).
2. **Reviewer memory, if the harness keeps any** —
   `.claude/agent-memory-local/<name>/` and `.claude/agent-memory/<name>/`,
   each with a `MEMORY.md` index; read both indexes, open entries whose
   subject the diff touches.
3. **History of the touched lines** — `git log -L` / `git blame` on the
   changed regions and `git log --all --oneline -- <decisions-path>` before
   concluding no record exists (an ADR often lands with its feature branch).
4. **Previous review threads** on the PR/MR (`gh pr view --json comments,
   reviews` / `glab mr view`) and code comments in the changed files — a
   comment that says *why* a line is the way it is is a standard too.

Apply it both ways:

- **Forward** — does this diff re-open something settled? Reversing an
  accepted decision, rebuilding an abandoned abstraction, reintroducing a
  mechanism removed for cause → a finding at the severity of the original
  problem, citing the record. Nobody reviewing the diff alone can produce it.
- **Backward** — is what you are about to flag deliberate? Before any finding
  about duplication, an "inconsistent" sibling, a missing abstraction, an odd
  hook split: check the record. If it explains it, **drop the finding
  silently** — a review that re-litigates settled decisions trains the author
  to skim.

Record and code genuinely disagree → say which you think is stale; that is a
finding addressed to both.

## 3. Fast pass — your own first read, capped

Before dispatching, do a quick first-principles scan of the diff you already
hold for **obvious, high-signal** issues only: a missing `await`, a swapped
argument, an enum/status added without its sibling `switch`, a null deref the
diff makes reachable, an Effect with a subscription and no cleanup, an
injection/XSS sink fed by user input. Quote the line. Do not read beyond the
diff for this.

Keep it as a pseudo-reviewer named `fast-pass`, **capped at MEDIUM confidence
on its own** and never counted as independent corroboration — it shares your
context and blind spots. Show it to the user only if it found a CRITICAL/HIGH
candidate, under a clearly *preliminary* header, and reconcile it in the final
report (survived / merged / withdrawn). Never seed it into the agent briefs.

## 4. Pick the roster and announce it

Read `references/personas.md`. Select by **risk in the diff, not by keyword**:
core personas always; each conditional only when its concrete surface is
present (a `.tsx` config file does not summon the React persona; a component
with three Effects and a fetch does). Fold matched installed skills into the
persona whose scope they fall in. Then tell the user the team in one line per
conditional persona with the *real* reason it was added:

`Reviewers: correctness, security, frontend-react (+react-compiler skill),
frontend-runtime — three Effects and a fetch on the checkout page;
ui-a11y-i18n — new form markup; standards — repo addendum names two defect
classes.`

Merge tiny buckets, split a huge one; a roster of 3–6 is typical.

## 5. Fan out — independent reviewer agents

Dispatch one `Agent` per persona **in a single message** so they run
concurrently, fresh context each, and only its own brief. Each brief contains,
verbatim: `<REF>`, the diff (or its staged path when large), the changed-file
list, the intent summary, the persona section from `personas.md`, the absolute
paths of its checklist file(s) to `Read`, the **names** of matched installed
skills to invoke with `Skill(<name>)` (the agent loads them; you never do), the
repo addendum's relevant criteria, the blast-radius reference list for the
symbols in its scope, the finding format below, and the read-only rule. Agents never see each
other's output — that independence is the point. Route a bucket to a matching
specialist agent type when the host has one (security → a security auditor);
otherwise a general agent. Do not pass a `mode` that bypasses the user's
permission settings.

Each agent returns candidates in this shape, nothing else:

```
[SEVERITY][confidence 50|75|100] Short title
File: path:line
Line: <verbatim line(s) that make it true>
Issue: what is wrong and why it matters (one or two sentences)
Class: static | runtime        (runtime → needs observation before HIGH+)
Fix: the concrete change
Source: <checklist file or skill name>
```

Confidence anchors, behavioural not vibes: **100** — verifiable from the code
alone (definitive logic error, quotable rule violation); **75** — full path
traced from input to wrong result and a normal user/caller hits it, with a
named observable consequence; **50** — real but narrow/nit, or depends on a
condition outside the diff. Below 50 → suppress, don't emit. Anchor and
severity are independent axes.

While agents run, do not poll with shell no-ops or wakeups; a foreground
`Agent` call is the wait.

## 6. Fan in — verifier agents try to refute

Deduplicate by (file, line, claim). Merge only findings that describe the same
defect and fix path; keep disagreements visible. Then hand each survivor at
HIGH+ (and any CRITICAL regardless of source, and any single-source finding)
to a **different** agent than the one that raised it, briefed to **refute**:
point at the exact line and prove it wrong, name the mitigation, or trace an
input that confirms it. Batch them into one verifier call ordered by severity
(a batch of ~8 is normal; expand rather than drop a HIGH). Findings the
verifier cannot substantiate are dropped and counted in Scope & evidence.
Two independent agents agreeing raises confidence; `fast-pass` agreeing does
not.

## 7. Observe — take runtime-class survivors to the real app

For every surviving finding whose `Class` is `runtime` (and for any HIGH+ UI
claim you can cheaply see), settle it by looking, not reasoning:

1. Find the launch path in the project's own docs (`CLAUDE.md`,
   `CLAUDE.local.md`, README, `package.json` scripts): dev command, port, how
   to get an authenticated session. Do not invent one. Starting the dev server
   is allowed (it emits no artifacts into the tree); prefer the host's preview
   tooling where it exists.
2. Drive it with `agent-browser` (snapshot → interact → snapshot; capture
   console errors and network requests around the case), or Playwright where
   the project already uses it. Reproduce the exact case the finding claims —
   the disabled control, the request that should/shouldn't fire, the guard,
   the value after save, the focus order, the layout at the breakpoint.
3. Record what you saw in one sentence and tag the finding `OBSERVED` —
   "opened `/orders/42`, changed the name, saved: the field is still editable
   and the new name persisted". If the claim did **not** reproduce, the finding
   dies (or drops to the mitigation you observed).

Only when the app genuinely cannot be reached — no dev command, no
credentials, a backend you don't control, no installed dependencies and no
mandate to install them, no entry point/route that renders the changed
component — does the finding stay `TRACED` at its capped MEDIUM. Say which
specific thing blocked you and move on; "didn't run it" on its own reads as
an unfinished review, and trying to boot an app that cannot boot wastes the
user's minutes.

**Checks the addendum asked for.** By default this mode does not run the
project's tests/typecheck/lint (CI's job; minutes spent reprinting a result).
When `.claude/review-skills.md` lists non-mutating checks under *Checks to run*,
run exactly those, scoped to the changed files where the tool allows, after
reading the script to confirm it does not chain a formatter `--write` or
codegen. Report results verbatim under **Observed / ran**; a failure is a
finding with `TESTED` evidence.

## 8. Report

Apply `references/standards.md`. In addition to the shared template:

- Scope & evidence's **Advanced** bullet carries the capabilities
  present/missing, the roster with reasons, blast-radius coverage, fast-pass
  reconciliation, verifier drop count, and any degraded-mode note; the
  **Observed / ran** bullet carries what was driven in the browser and what
  the addendum's checks returned.
- Each CRITICAL/HIGH paragraph names the persona that raised it and that the
  verifier upheld it (or that it survived because it was `OBSERVED`).

## Degraded mode — advanced requested, a capability missing

Run the same shape sequentially and say so:

- No `Agent` → review one persona at a time yourself as self-contained passes,
  writing each candidate in the §5 finding shape to a scratch note as you go,
  then re-examine every candidate adversarially in a separate pass before it
  ships. Independence is weaker, so hold the >80% bar more strictly.
- No graph/LSP → `rg` per identifier, coverage declared as grep-only, and
  confidence lowered on any "nothing else uses this" claim.
- No browser → runtime-class findings stay `TRACED`/MEDIUM with repro steps;
  the report names the missing capability.

Never present a degraded run as the full thing.
