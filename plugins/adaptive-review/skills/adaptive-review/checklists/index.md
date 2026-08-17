# Checklist index — single source of truth for what to load

The spine (Step 3 of `SKILL.md`) reads this table and loads **only** the rows
whose triggers match a changed file: every `Always` row plus the matching stack
rows. Both modes use it; advanced mode additionally hands each row to the
persona that owns it (`references/personas.md`).

To add a checklist: create `checklists/<group>/<name>.md` (severity-tagged
title, scannable bullets, BAD/GOOD snippets where they help, a *What not to
flag* section) and append one row here. Nothing else changes.

## Core — stack-agnostic

| Checklist | Default severity | Triggers | Scope (one line) |
| --- | --- | --- | --- |
| `core/intent-and-correctness.md` | HIGH | Always | Spec vs code axes, concrete-input trace, sentinels, edge cases, state/transaction integrity, idempotency, time/money/units. |
| `core/user-perspective.md` | HIGH | Always (yields nothing for pure internal plumbing — say so) | User journey, user-driven edge cases, failure → symptom, async feedback. |
| `core/security.md` | CRITICAL | Always | Secrets/env exposure, injection, XSS/output encoding, authn/authz, redirects/SSRF/traversal, sensitive data, dependency integrity. |
| `core/performance.md` | MEDIUM (HIGH on a hot path) | Always | Data access (N+1, unbounded), loops, I/O, caching, footprint, **frontend rendering/loading**. |
| `core/code-health.md` | HIGH (hygiene LOW) | Always | Structure, error handling, dead code, naming, complexity, elegance, named remedies, hygiene/PR size. |
| `core/tests.md` | MEDIUM | Diff adds/modifies tests, or changes behaviour that tests cover/should cover — **skip when the project has no test layer** (check the manifest / test config first) | Do the tests prove anything; prove-it test for bug fixes; frontend test traps; one umbrella gap finding. |
| `core/dependencies.md` | MEDIUM | A manifest changed (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, …) | Necessity, provenance, weight, version style, major-bump notes, leftovers, lockfile. |

## Frontend — React / TypeScript / Next.js

| Checklist | Default severity | Triggers | Scope (one line) |
| --- | --- | --- | --- |
| `frontend/typescript.md` | HIGH | `*.ts`, `*.tsx`, `*.mts`, `*.cts` | Strict typing, no `any` leak, null handling, discriminated unions/exhaustiveness, type design, async typing. |
| `frontend/react.md` | HIGH | `*.jsx`, `*.tsx` containing components or hooks | Stale closures & dep intent, needless Effects, cleanup, keys, state identity, memo defeats, external stores, controlled inputs, React 19 APIs, short a11y list. |
| `frontend/frontend-runtime.md` | HIGH (runtime-class items only → MEDIUM until observed; leaks/no-cleanup are static-class, full strength) | The diff touches Effects, timers, subscriptions, listeners, fetches, routing, optimistic updates, submitting forms, websockets, storage sync, or a UI state machine | Effect exit paths, async work outliving its trigger, concurrent interactions, navigation, data-layer semantics, real-world conditions to drive. |
| `frontend/ui-a11y-i18n.md` | HIGH / MEDIUM | Markup, UI-rendering components, forms, styles/CSS/Tailwind, user-facing strings | Semantics & names, keyboard/focus, forms, colour/motion, responsive layout & design system, i18n (only where the project localises). |
| `frontend/nextjs.md` | HIGH | Next.js projects: `app/**`, `pages/**`, route handlers, server actions, `proxy.ts`/`middleware.ts`, `next.config.*` | Server/client boundary, server actions, caching/revalidate, `NEXT_PUBLIC_` env, `next/image`/`next/link`, route handlers. |

## Selection notes

- A `.tsx` component loads `typescript.md` **and** `react.md`; inside a Next.js
  project it also loads `nextjs.md`. `frontend-runtime.md` and
  `ui-a11y-i18n.md` are content-triggered — read the hunks, not just the
  extension.
- Installed tech-stack skills on the host (e.g. `react-compiler`,
  `react-effect-event`, a project's Next.js skill) are discovered at review
  time and layered on the row whose file types they cover; they are not
  registered here because they vary per host.
- The repo addendum (`.claude/review-skills.md`) may list **extra checklists**
  by path with their own triggers; load them alongside these.
- A finding's severity defaults to the row's tier and may move up or down for
  the specific case (`references/standards.md`).

## Reserved groups (not shipped yet)

`backend/` (Node/Express/Nest, Python, Go, …), `mobile/` (React Native, Expo),
`data/` (SQL, migrations). Add a directory, its files, and rows above; the
spine and the personas file pick them up without any change to `SKILL.md`.
