# Standards — evidence, severity, the disprove pass, the report

Owned by Step 5 of `SKILL.md`, shared by both modes. This file decides *how
to judge* and *how to present*; the checklists decide *what to look at*.

## Finding tiers — what is "your code to review"

- **Primary** — lines this branch added or modified. Full confidence.
- **Secondary** — unchanged code in the same function/block whose behaviour
  the change alters (a new caller now hits an old buggy path). Report it, and
  say the issue lives in the interaction between new and old code.
- **Pre-existing** — untouched code the diff does not interact with. Not
  reported, except a CRITICAL security hole in the surrounding code, which is
  reported and labelled *pre-existing*; it does not move the verdict.

Test: would you flag the same issue on an identical diff that did not include
the surrounding file? Then it is pre-existing.

## Evidence tiers — tag every finding with how you know

| Tier | Meaning |
| --- | --- |
| `OBSERVED` | You ran the real thing — the app in a real browser (agent-browser / Playwright), the real CLI/server — and saw it happen |
| `TESTED` | A test that was actually executed passes/fails on exactly the point at issue (a run you did, or a CI/e2e result the user handed you) |
| `TRACED` | Code reading and reasoning only — no execution |

`TRACED` is full-strength evidence for **static-class** findings — ones the
source fully determines: wrong formula, null/off-by-one, broken caller
contract, injection, hardcoded secret, dead code, missing validation, a
`key` that swaps component identity, an Effect without cleanup. Read the code,
trace a concrete input, report at whatever severity the impact warrants.

### Runtime-class findings — reading code does not settle them

A separate class depends on the **real runtime's ordering and state**, which
the source text does not contain:

- framework effect / batching / scheduler order — which render or commit lands first
- event-loop races: `await` continuation vs a state update vs a subscription callback
- browser history stack, routing, back/forward, navigation guards
- DOM / CSS / layout / focus / real event dispatch / hydration mismatch
- data-fetch order, cache/revalidation timing, loading and error states as actually shown
- backend concurrency: locks, retries, transaction and message ordering

A headless simulation (jsdom, fake timers, mocked router, `act()`-wrapped
render) is a hypothesis, not proof — its scheduling is an artifact of the
harness. To reach `OBSERVED` on a runtime-class claim, run it in the real
environment (advanced mode does this with `agent-browser`), or instrument the
two points whose order is in dispute and read the order off the real run.

**The line between the two classes:** a defect that exists *regardless of
ordering* — a listener with no `remove`, an interval with no `clear`, a
subscription opened twice, an Effect that mutates a global on an early-return
path — is static-class: the leak is there on every run. A defect that only
manifests *when* things happen in a particular order — a stale response
overwriting a fresh one, a guard bypassed by back/forward, a double submit — is
runtime-class, even when the missing guard is obvious from the code.

## Severity

Each finding gets exactly one level:

- **CRITICAL** — merge blocker. Exploitable security hole (XSS, injection,
  leaked secret, auth bypass), data loss/corruption, broken core business
  logic, production crash, a contract change that breaks callers.
- **HIGH** — fix before merge. Clear correctness bug of narrower scope: race,
  unhandled business edge case, missing important validation, hot-path
  performance regression, error handling that swallows failures, an Effect
  that leaks or double-fires in production.
- **MEDIUM** — fix, not a blocker. Quality/maintainability: missing tests for
  important logic, duplication, misleading naming, complexity, performance
  outside hot paths, a11y gap on a secondary surface.
- **LOW** — nice-to-have. Style-adjacent, minor naming, micro-optimisation,
  non-urgent refactor.

Two calibration notes for common frontend cases: a **render crash reachable by
ordinary input on a primary path** is HIGH by default, CRITICAL only when you
can see it takes the whole app down (an app root in the repo with no error
boundary above the crash) or corrupts data — when the root/boundary lives
outside the repo, or the repo has no app root at all, say so and stay at HIGH. A finding raised by **two checklists** (e.g. `<div onClick>` from both
`react.md` and `ui-a11y-i18n.md`) is reported **once**, attributed to the more
specific source.

Three rules decide the final level, in order:

1. **Evidence caps severity.** For a **runtime-class** finding, `TRACED` and
   simulated `TESTED` cap at **MEDIUM**; only `OBSERVED` unlocks HIGH/CRITICAL.
   Static-class findings are not capped. If you cannot reach `OBSERVED` and
   believe the issue is serious, do not promote it — report at the capped
   level and hand the user the exact steps to settle it. Self-check before any
   HIGH/CRITICAL: *could this be an artifact of the environment I reasoned or
   ran in?*
2. **Severity realism.** Worst case in the *real* system, not in isolation. A
   later gate, validation, error boundary, or compensating control that makes
   the worst case unreachable → downgrade honestly and name the mitigation.
3. **Torn between two levels → the higher one, and say why.** Applies only to
   impact you have evidence for; it never launders a guess into a HIGH.

## The disprove pass — mandatory, both modes

Finding and judging are different modes. After the sweep, switch sides and try
to **kill** every candidate before it reaches the report:

- **Re-read the exact cited lines.** Is the claim about the code that is
  there, or about a paraphrase built up while sweeping?
- **Hunt for the mitigation:** a later gate, default, caller-side check, error
  boundary, Suspense/loading state, an existing test that pins the case.
- **Recompute the concrete trace** with real values once more.
- **Check the other layers:** handled on the target side (drift), in an
  untouched sibling, or pre-existing on `<REF>` rather than introduced here?
- **Check the record:** does an ADR, plan, or reviewer memory already explain
  the pattern as deliberate? Then the finding dies silently.

Survivors go in. Dead ones are dropped **silently** — never pad the report
with disproved candidates. One you can neither confirm nor kill goes in at its
evidence-capped severity with the exact steps to settle it.

## Report

Prose (overview, business-logic narrative, issue descriptions, fix rationale,
what looks good, verdict reason) in the user's conversation language. English
regardless: section headings, severity levels, categories, evidence tiers,
verdict words, `file:line` refs, symbol names, sample code and its comments,
branch/commit names.

```markdown
## Adaptive Review (<minimal|advanced>): <current branch> → <REF>

### Overview

<1–3 sentences: what the diff does, overall quality, whether it should merge>

### Scope & evidence

- **Mode:** <minimal|advanced> — <auto/user-chosen; if degraded, which capability was missing>
- **Compared against:** <`origin/<TARGET>` or local fallback; user-supplied or auto-detected; fetch-failed note>
- **Reviewed:** <files read; uncommitted/untracked folded in or skipped; drift result; stacked split; advanced: blast-radius coverage, e.g. "read 8 of 41 references, one per surface group">
- **Criteria:** <checklists loaded, installed skills applied, addendum items — mark addendum-required>
- **Advanced:** <only in advanced mode — capabilities present/missing; roster with the one-line reason per conditional persona; blast-radius coverage; fast-pass reconciliation (raised / merged / withdrawn); verifier drop count; degraded-mode note if any>
- **Observed / ran:** <advanced: what you drove in the browser and what checks the addendum asked you to run, with results — or exactly `nothing — static review; all findings TRACED`>
- **Not run:** tests / typecheck / lint (CI's job) unless listed above

### Summary

| Severity    | Count |
| ----------- | ----- |
| 🔴 CRITICAL | x     |
| 🟠 HIGH     | x     |
| 🟡 MEDIUM   | x     |
| 🔵 LOW      | x     |

### 🧠 Business logic & intent

<The most important section. The intent you reviewed against and where it
came from; whether the change achieves it; regression / broken-contract /
sibling-divergence risk; scope creep outside the stated intent.>

### Issues

CRITICAL → HIGH → MEDIUM → LOW.

| #   | Severity | Evidence | File:Line | Category | Issue | Fix |
| --- | -------- | -------- | --------- | -------- | ----- | --- |

<Category: Business / Security / Performance / Correctness / Maintainability / A11y / Standard:<checklist or skill name>>

Any runtime-class finding at HIGH/CRITICAL must show `OBSERVED`; otherwise it
is capped at MEDIUM and names the steps to settle it.

For each CRITICAL and HIGH, a short paragraph below the table: **the verbatim
line(s) that make it true** (the quote-the-line gate lives here), the concrete
trace, why it is wrong, and a sample fix (code where it helps). Advanced mode
adds the reviewer persona that raised it and that the verifier upheld it.

### ✅ What looks good

- <grounded observations — a specific line you read and a concrete input you followed, never a vibe>

### Verdict

**Approve** / **Request changes** / **Needs discussion** — <one-line reason>
```

## Verdict rules

- Any CRITICAL → **Request changes**.
- Any HIGH → default **Request changes**; a genuinely debatable HIGH may be
  **Needs discussion** — say why.
- Only MEDIUM/LOW → may **Approve** with notes.

Approve a change when it clearly improves the codebase's health even if it is
not perfect — MEDIUM/LOW are advice, not gates. Praise is informational and
never moves the verdict.

## Principles

- Cite `file:line`; no vague statements. Each issue: why it is wrong + how to
  fix.
- Unsure about intent → state the assumption you used instead of guessing.
- Honest: good code gets called good; no invented problems to fill a quota.
- **Ground before you praise** — every "correct"/"looks good" claim traces to
  lines you read or something you observed.
- **Never launder a guess into a severity.** State how you know before how
  bad; if the evidence tier does not support the level, lower the level.
- Never write "tests pass" / "typechecks clean" / "✅ verified" about a run you
  did not perform.
