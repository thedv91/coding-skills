# Minimal mode — a careful checklist walk, nothing more

The whole point of this mode is that it costs one context, no agents, no MCP
servers, no browser — it runs the same on a laptop with nothing installed as
on a fully wired machine. Its evidence ceiling is `TRACED`, and its report says
so. Do not "helpfully" reach for codegraph, serena, `Agent`, or a browser
here; if the diff turns out to need them, finish the minimal pass and tell the
user which findings advanced mode would settle.

Inputs from the spine: `<REF>`, the diff, the changed-file list, the intent
summary, the selected checklists (`checklists/index.md`), any installed
tech-stack skills matched, and the repo addendum.

## 1. Read the changed files whole, not the hunks

For every changed source file, read the full file (`Read`, or one `cat -n` over
several small files — whichever is fewer round-trips). A line that looks wrong
in a hunk is often right in context — and the reverse. Skip generated/lock
files (noted, not reviewed).

For a changed **exported** symbol (function, hook, component, type, constant),
you still owe its consumers a look — minimal mode does it with `Grep` for the
symbol name across the source tree, and reads the hits. Say in Scope &
evidence that consumer coverage is grep-only (re-exports, aliases, barrel files
and dynamic dispatch can hide callers), and lower confidence on any finding
that rests on "nothing else calls this".

## 2. One pass per checklist bucket

Walk the checklists in this order, one bucket at a time, so each lens gets a
clean look instead of everything blurring into one skim:

1. **Intent & correctness** — `core/intent-and-correctness.md`. Trace a
   concrete input (real values) through every non-trivial change; compute
   what each line yields.
2. **User perspective** — `core/user-perspective.md`.
3. **Security** — `core/security.md`.
4. **Stack checklists** — the `frontend/*` rows the index selected (React,
   TypeScript, Next.js, runtime, UI/a11y/i18n), plus any installed tech-stack
   skill's rules for the files in its scope.
5. **Performance** — `core/performance.md`.
6. **Code health & tests** — `core/code-health.md`, `core/tests.md`.
7. **Dependencies** — `core/dependencies.md`, only if a manifest changed.
8. **Repo addendum** — its defect classes and criteria, last, so they are
   checked with the code already in your head.

Per checklist, note candidates as `[severity-tier default] file:line — claim —
the verbatim line`. A candidate with no verbatim line is not a candidate yet.

## 3. Sibling divergence — the cheapest high-yield check

When two surfaces do the same job (desktop ↔ mobile variant, inline path ↔
tooltip/detail path, sibling switch branches, `create` ↔ `edit` form), diff
them against each other. A change applied to one and not the other is the #1
bug shape in UI diffs and needs no tools to find.

## 4. Disprove, then report

Apply the disprove pass and the report from `references/standards.md`. In
**Scope & evidence** write:

- `Mode: minimal — checklist walk; consumers found by grep only`
- `Observed / ran: nothing — static review; all findings TRACED`

Runtime-class candidates (see standards → runtime-class) are reported at their
capped MEDIUM with the exact repro steps, and the report closes with a one-line
pointer: *"N runtime-class findings would be settled by `adaptive-review
advanced`."* — only when N > 0.
