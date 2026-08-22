---
name: testid-instrumentation
description: >
  Add stable `data-testid` attributes to UI code so e2e tests get selectors that survive
  refactors AND an inspected DOM node greps straight back to the component that rendered
  it — one attribute, both jobs. Use whenever the user asks to "add data-testid", "make
  this testable / e2e-ready", "add test selectors", "instrument this page for Playwright /
  Cypress / Testing Library", or is about to write e2e tests against a screen with no
  reliable selectors. Use it just as much for the debugging half, even when tests are never
  mentioned: "which component renders this element?", "I inspected the DOM and can't find
  it in the code", "make components findable from the browser", or a pasted HTML snippet
  someone wants traced back to source. Detects the project's existing attribute name and
  naming convention first and follows it — it never imposes one. Framework-agnostic
  (React/JSX, Vue, Angular, Svelte, Solid, web components, server-side templates).
license: MIT
metadata:
  version: "1.0.0"
---

# testid-instrumentation — one `data-testid`, two jobs

A single test-id attribute serves both purposes, so **never introduce a second attribute for
component identity**. One value, two readers:

- **e2e tests** — a selector that survives refactors, restyles and i18n.
- **a human or agent inspecting the DOM** — copy the value, `rg` it, land on the source.

Identity comes for free from the *value*, not from a second attribute: any test id that
appears **literally in source** is already a one-grep route back to the file that rendered
it. That is the whole trick — and it only holds while the five rules below hold.

## The five rules that make one attribute do both

Everything else in this skill exists to serve these. Break one and the identity half
silently stops working — tests keep passing, so nothing warns you.

1. **The value must exist literally in source.** `data-testid={id}` or
   `` data-testid={`${prefix}-${kind}`} `` is invisible to grep. Dynamic ids keep a static
   literal prefix: `` data-testid={`user-row-${user.id}`} `` — `rg 'user-row-'` still finds it.
2. **The value must be unique across the codebase** — one value, one source location.
   The only exception is a repeated template (list rows), where the *many* DOM nodes still
   come from *one* line of source. That is still identity.
3. **The prefix names the component that renders it**, in the project's casing:
   `payment-summary-submit` ⇄ `PaymentSummary`. This buys the reverse mapping even when
   the tail of the id is interpolated, and it makes rule 2 almost automatic.
4. **Components worth finding get a root anchor id** — the component's own bare name on its
   root element (`data-testid="payment-summary"`). Tests may never use it; it is what makes
   an arbitrary DOM node traceable to a file. This is the one id that is added for the
   identity job alone, so keep it to components that matter (see Phase 1). A reused
   component's anchor appears many times in the DOM and still exactly once in source — that
   satisfies rule 2, which is about the *source*, and it is why an anchor is a poor thing
   for a test to select on its own. Tests scope through it (`within(...)`), they do not
   assume it is alone.
5. **If the build strips the attribute, identity dies in production.** This is the real
   cost of merging the two jobs — see Phase 0 step 5, and decide it consciously.

**Instrument sparingly anyway.** Every added attribute is API surface someone must not
rename. An id on every `div` is noise that makes the real ones invisible — and it breaks
rule 2 faster than anything else.

## Modes

1. **Instrument a scope** — a component, feature, page, or route the user names.
2. **Instrument for a flow** — the user has (or is about to write) an e2e test; add ids for
   exactly the elements that flow touches, plus root anchors on the components involved.
3. **Reverse lookup** — the user pastes inspected HTML and wants the source. Jump straight
   to [Reverse lookup](#reverse-lookup-inspected-html--source); the phases below are for
   modes 1 and 2.

An open-ended "add test ids everywhere" is not a scope. Survey first (Phase 0), then
propose a bounded slice — one feature, one route, the components a named flow touches — and
confirm it. A 300-file attribute sweep is unreviewable, and unreviewed ids are how rule 2
gets broken at scale.

## Phase 0 — Detect the project's conventions (never invent them)

Run these before editing anything. **What the repo already does wins over every default in
this file**, including the naming shape in Phase 2 — a literal id is greppable whatever its
grammar, so never renumber an existing scheme to match this document.

`scripts/testid-scan.sh` runs the surveys below and the checks in Phase 4. Call it by
absolute path (`<skill-dir>/scripts/testid-scan.sh`, last argument = the path to scan)
while your working directory stays in the target project. Use it rather than retyping the
ripgrep: a mangled quote reports "no convention here", which is the worst wrong answer
this phase can produce.

1. **Which attribute?** The default is `data-testid`, but many repos use `data-test`,
   `data-cy`, `data-qa`, `data-automation-id`. Count actual usage:

   ```bash
   scripts/testid-scan.sh census .
   ```

2. **What do the test tools expect?** These must agree with the attribute you add:
   - Playwright: `use.testIdAttribute` in `playwright.config.*` (default `data-testid`;
     a comma-separated list matches several).
   - Testing Library: `configure({ testIdAttribute: '...' })` in the test setup file.
   - Cypress: usually a custom command or `@testing-library/cypress`; read the existing
     selector helper rather than guessing.
   - If config and code disagree, say so and ask which is authoritative — do not silently
     pick one.
3. **What is the existing naming shape?** Sample real values and copy their grammar
   (separator, casing, namespaced by feature or by component):

   ```bash
   scripts/testid-scan.sh values data-testid . | head -50
   ```

   Also check how many are **already dynamic** — `rg -n 'data-testid={' ` finds the
   interpolated ones. Those are the existing blind spots for the identity job, worth
   reporting even if you do not fix them.
4. **Is there a lint rule or a per-repo doc?** eslint plugins that require or forbid the
   attribute, a `.claude/`-level convention file, `CONTRIBUTING.md`, a testing README.
   Follow it verbatim.
5. **Is the attribute stripped in production?** Look for `compiler.reactRemoveProperties`
   (Next.js — default regex `^data-test`), `babel-plugin-react-remove-properties`, or a
   bundler equivalent. **This is the collision point of the two jobs:** stripping is right
   for test selectors and fatal for debugging a production DOM. If it is on, say so plainly
   — identity then only works in dev/staging builds, and the choice (keep stripping, drop
   it, or strip only a sub-prefix) belongs to the user, not to you.
   See [references/frameworks.md](references/frameworks.md).
6. **Which framework and how do attributes reach the DOM?** Passing an attribute to a
   *component* is not the same as putting it on a DOM node — read
   [references/frameworks.md](references/frameworks.md) before touching JSX/SFC/templates.

If the project has **no** convention at all, state that you are introducing one, use the
defaults below, and keep it consistent across the whole change.

## Phase 1 — Decide what gets an id

Two lists, because the two jobs want different things.

**For tests** — test ids are the *fallback*, not the first choice. Prefer selectors that
assert something a user perceives (role + accessible name, label text) because they break
when the UX breaks. Add a test id when:

- The element has **no stable accessible name** (icon-only button, avatar, canvas, chart, a
  `div` acting as a control).
- Its text is **dynamic, translated, or duplicated** on the page (several "Save" buttons,
  i18n'd labels, formatted numbers).
- The test needs a **container to scope inside** — row, card, modal, drawer, toast.
- It is a **state surface** to assert on: error message, empty state, loading skeleton,
  badge/count, success banner.
- The current selector is **structural and brittle** (`.css-1x2y3z`, `nth-child`, deep
  descendant chains). Replacing those is the highest-value work here.

**For identity** — one root anchor per component that someone would plausibly need to find:
screens, routes, feature sections, cards, rows, modals, anything with real logic inside.
Skip it for leaf primitives that render hundreds of times (`Button`, `Icon`, `Text`,
layout/spacing wrappers) unless the user asks — the DOM weight is real and the answer there
is usually "it's the design-system Button", which nobody needed an attribute to learn.

Do **not** add ids to decorative nodes, elements already reachable by a stable role+name
that no test needs to scope into, or anything under a generated/vendored directory.

Before adding, check whether the element is already reachable and already traceable. A
skipped addition with a stated reason beats a redundant attribute.

## Phase 2 — Name the id

Follow the repo's grammar if one exists. Otherwise default to lowercase kebab-case,
prefixed with the component's own name:

```
<component-kebab>[-<element>][-<qualifier>]

payment-summary                     # root anchor  → PaymentSummary
payment-summary-submit              # the button   → PaymentSummary
user-table-row-<userId>             # list row     → UserTableRow
settings-profile-avatar-upload      # nested       → SettingsProfile
```

The mapping value ⇄ symbol must be **mechanical in both directions**: kebab-case the
component symbol to get the prefix, PascalCase the prefix to get the symbol back. Do not
abbreviate one side (`pmt-summary-submit` costs you the reverse lookup for nothing).

Then:

- **Semantic, not positional.** `-row-3` breaks on sort/filter/pagination. Use a stable
  business key: `user-table-row-${user.id}`. With no stable key, put the id on the container
  and let the test scope by visible content inside it.
- **Never interpolate user data or PII** (email, name, token, order note). It leaks into the
  DOM and into test logs, and test logs travel further than the DOM does. Interpolate opaque
  ids only.
- **Stable across refactors.** The id describes the element's job, not its current markup,
  wrapper, or CSS class. Renaming a styled wrapper must not change it. Renaming the
  *component*, however, should — keeping the prefix truthful is the whole of rule 3.

A full before/after on one card — which nodes earn an id, which stay bare, and what the
diff looks like — is in [`references/worked-example.md`](references/worked-example.md).

## Phase 3 — Apply the edits

- **Idempotent.** Grep for the attribute on the element before adding; never produce two ids
  on one node, never silently overwrite an existing value.
- **Attribute passthrough is framework-specific and is where this goes wrong.** An id handed
  to a custom component often never reaches the DOM. Read
  [references/frameworks.md](references/frameworks.md) for the target framework first, and
  prefer putting the attribute on the DOM element itself over threading it through a
  component that does not forward props.
- **Typed props when threading is unavoidable.** In TypeScript, declare an explicit optional
  prop (`'data-testid'?: string`) rather than widening the props type to `any` or spreading
  unknown rest props into the DOM.
- **Root anchors go on the component's outermost DOM element** — the one it actually renders,
  not a parent's wrapper, or the anchor points at the wrong file.
- **Minimal diff.** Attribute additions only. No reformatting, no reordering props, no
  "while I'm here" refactors. Keep the attribute next to the other identity-ish props
  (`id`, `name`, `role`) so diffs read cleanly.

## Phase 4 — Verify (do not skip)

1. **The grep round-trip — this is the definition of done for the identity job.** For every
   id you added, run the lookup a developer would run from devtools and confirm it lands on
   your file, once:

   ```bash
   scripts/testid-scan.sh find payment-summary-submit .
   ```

   (It retries on the static prefix automatically, which is what a dynamic id needs.) Zero
   hits means you broke rule 1; several unrelated hits mean you broke rule 2. Fix the value,
   not the grep.
2. **Nothing existing was renamed.** For every id you touched, `rg` the whole repo —
   including tests, page objects, selector constant files, and analytics/tracking code that
   may key off the same attribute.
3. **Unintended duplicates:**

   ```bash
   scripts/testid-scan.sh dupes data-testid .
   ```

   Every survivor must be an intentional shared template. Explain each one you keep.
4. **The attribute actually lands in the DOM.** Static edits are not proof — a component that
   drops unknown props renders nothing. Confirm by rendering: a component/e2e test, a dev
   server plus a DOM query, or a snapshot. If you could not render it, say **unverified** and
   name what you skipped.
5. **The project's own checks** — typecheck, lint, and the test suite for the touched area,
   once at the end. Report real output, not an assumption.

## Phase 5 — Report

Keep it to this shape. The reader's two questions are "what is now selectable?" and "what
did you decide on my behalf?" — the skipped list and the caveats answer the second, so do
not drop them just because they are the boring half.

```
**Convention**: <attribute> + <naming grammar>, found in <where> / newly introduced.
**Added** (n): <id> → <file:line>, one line each, grouped by component.
**Root anchors**: <components that got one>.
**Skipped**: <element or component> — <why: already reachable, leaf primitive, generated code>.
**Untouched**: <existing ids left alone, and which tests depend on them>.
**Verified**: grep round-trip <pass/fail>, duplicates <none/list>, DOM observed via <how> or
  **unverified — <what you could not run>**.
**Caveats**: production stripping <on/off and what that costs>, passthrough you had to add,
  anything the team must keep doing.
```

## Reverse lookup: inspected HTML → source

Given a DOM snippet from devtools:

1. **Grep the id literally:** `rg -n 'payment-summary-submit'`. Instrumented code ends here.
2. **Interpolated id?** The full value will not match — grep the static prefix
   (`rg -n 'user-table-row-'` finds `` `user-table-row-${user.id}` ``).
3. **Still nothing? Walk up the DOM** to the nearest ancestor that has an id — the root
   anchor names the owning component even when the leaf is bare.
4. **Convert prefix → symbol** and search the component itself: `payment-summary` →
   `rg -n 'PaymentSummary'`, filtered to its definition/export.
5. **No instrumentation at all** → fall back to distinctive nearby text (mind i18n: search
   the message catalog for the string, then grep the key), then a stable class or
   `aria-label`. Generated hash classes (`css-1x2y3z`) are dead ends — do not burn time.
6. Then **offer to instrument** what you just hunted for, so the next lookup is step 1.

Framework devtools (React/Vue/Svelte extensions) map an element to a component tree in dev
builds; use them when available. The point of rule 1 is that grep still works where they
are not — a production build, a bug report screenshot, a colleague's pasted HTML.

## Guardrails

- **Existing ids are a contract.** Renaming one breaks tests you may not be able to run.
  Check first; if a rename is genuinely needed, list every call site and ask.
- **Never fake verification.** "Added the attribute" is not "the attribute renders", and not
  "the grep round-trip passes".
- **Do not add a second attribute** for component identity. If the value cannot carry the
  identity, the value is wrong — fix rules 1–3 instead of adding DOM weight.
- **No test ids in production-critical logic.** They are for tooling; never branch app
  behavior on them, never use them as CSS hooks or as React `key`s.
- **Do not instrument generated, vendored, or third-party code** — the next codegen run
  erases it. Instrument the wrapper the project owns.
- **Do not rewrite the tests** while instrumenting unless asked; adding selectors and
  changing assertions are separate changes.
- Persisted artifacts (attribute values, code comments, commit messages) in **English**;
  converse in the user's language.
