# Framework notes — where the attribute actually lands, and what strips it

Read the section for the target framework **before** editing. The recurring failure is
putting an attribute on a *component* and assuming it reaches a *DOM node*. It usually does
not, and a static diff will not tell you.

Two cross-cutting reminders, since one attribute carries both jobs:

- **Root anchor** = the component's bare name as a test id, on the outermost DOM element the
  component itself renders. That is what makes an arbitrary node traceable to a file.
- **Stripping the attribute in a production build removes the identity too.** Decide it
  consciously and report it.

Verify the config claims below against the project's installed versions — options move.

---

## React / JSX

- On an intrinsic element (`<div>`, `<button>`) any `data-*` attribute renders as-is, and
  TypeScript does not typecheck hyphenated attributes there.
- On a **custom component** it is just a prop. It reaches the DOM only if the component
  forwards it — typically `const { onClick, ...rest } = props` plus `<button {...rest}>`. A
  component that destructures its known props and drops the rest silently swallows it.
- When you must thread it through, declare it explicitly instead of widening the type:

  ```tsx
  type Props = { label: string; 'data-testid'?: string };
  export function IconButton({ label, ...rest }: Props) {
    return <button aria-label={label} {...rest} />;
  }
  ```

- Prefer putting the attribute on the DOM element inside the component (or on a wrapper you
  own) over adding a forwarding path that did not exist before.
- Root anchor: `<section data-testid="payment-summary">` at the top of `PaymentSummary`.
  Watch fragments — a component returning `<>…</>` has no single root element; put the anchor
  on the outermost element that actually renders, or skip the anchor rather than adding a
  wrapper `div` for it.
- React DevTools already maps a node to a component in dev builds. The attribute is what
  still works in a production build, in a bug report, or in pasted HTML.
- **Stripping in production:**
  - Next.js: `compiler.reactRemoveProperties: true` removes props matching the default
    `^data-test` regex; `{ properties: ['^data-custom$'] }` for a custom set (the regexes run
    in Rust, so the syntax differs from JS `RegExp`).
  - Other bundlers: `babel-plugin-react-remove-properties`, or the bundler's own equivalent.
  - With a single attribute doing both jobs, turning this on means production DOM is no
    longer traceable. If the team wants both, the options are: ship the attributes (usually a
    few bytes per node), or strip only a naming sub-prefix reserved for pure test hooks while
    root anchors survive. Present the trade-off; do not pick silently.

## React Native

No DOM. The equivalent is the `testID` prop on core components, which maps to the platform
accessibility identifier that Appium/Detox/Maestro query. Naming, uniqueness and the grep
round-trip still apply — `testID` values are just as greppable. Nothing about `data-*` does.
Custom components must forward `testID` the same way React components forward props.

## Vue

- Non-prop attributes **fall through** to the single root element automatically, so
  `<MyButton data-testid="checkout-submit" />` usually works.
- It breaks in three cases:
  - `inheritAttrs: false` (also via `defineOptions({ inheritAttrs: false })` in
    `<script setup>`) — bind manually with `v-bind="$attrs"` on the element you want.
  - **Multi-root** components have no automatic fallthrough; Vue warns until `$attrs` is
    explicitly bound to one root.
  - Fallthrough lands on the root, which may be a styling wrapper rather than the control the
    test needs to click. Put it on the inner element instead.
- Dynamic values need a binding: `:data-testid="`user-row-${user.id}`"` — keep the static
  prefix inside the template literal so grep still finds the line.
- Root anchor: a static `data-testid` on the SFC's root element. Beware it can be overwritten
  by a fallthrough id passed by the parent — if both matter, bind explicitly rather than
  relying on fallthrough.

## Angular

- Static: `data-testid="checkout-submit"`. Dynamic **must** go through the attribute binding
  — `[attr.data-testid]="'user-row-' + user.id"`; plain `[data-testid]` binds a DOM property
  that does not exist. Keep the literal prefix as a string constant in the template so it
  stays greppable.
- For the component's own host element: `@Component({ host: { 'data-testid': 'user-card' } })`
  or `@HostBinding('attr.data-testid')`.
- Identity is often already free here: the component's selector is the rendered tag
  (`<app-user-card>`), which greps straight back to the `@Component` decorator. Add a root
  anchor only where the tag is generic (`<div>` hosts, directives, dynamic outlets).
  Angular's own `_nghost-*` / `_ngcontent-*` attributes are build-generated and useless as
  selectors — never key tests off them.

## Svelte

- On elements, plain attributes work; dynamic is `data-testid={`user-row-${user.id}`}`.
- On components it is a prop, forwarded only if the component spreads it:
  - Svelte 5: `let { variant, ...rest } = $props()` then `<button {...rest}>`.
  - Svelte 4 and earlier: `$$restProps` (`<button {...$$restProps}>`).
- Root anchor: on the markup root of the `.svelte` file, named after the file's component.

## Solid

Like React in shape, but props are reactive getters — split rather than destructure:
`const [local, rest] = splitProps(props, ['label'])`, then `<button {...rest} />`.
Destructuring props directly breaks reactivity, so do not "fix" a passthrough that way.

## Web components / shadow DOM

- An attribute on the host element is always reachable.
- Inside an **open** shadow root, Playwright pierces automatically; most DOM-based utilities
  (including Testing Library queries) do not.
- Inside a **closed** shadow root nothing external can reach it — instrument the host, or
  expose internals deliberately via `part=` and `::part()`.
- Prefer one id on the host plus property/state assertions over instrumenting deep internals
  a consumer cannot select anyway. The host id doubles as the root anchor.

## Server-side templates (Blade, ERB, Twig, Django, Handlebars, JSP, Go templates)

- Attributes are literal text — the simplest case, no passthrough problem.
- Root anchor: name it after the **partial**, so the value greps to the file
  (`data-testid="user-card"` for `components/user_card`). Pick one transform between path and
  value and keep it identical everywhere.
- Watch for the same partial rendered in several contexts: element-level test ids belong to
  the include site (pass them in as a template variable), while the root anchor belongs to the
  partial itself. A variable-supplied id is invisible to grep from the partial — the anchor is
  what keeps that node traceable.
- Stripping usually does not exist for these stacks. Decide consciously whether the attributes
  ship, and say so.

## Test-runner configuration (must match the attribute you add)

- **Playwright** — `use: { testIdAttribute: 'data-testid' }` in `playwright.config.*`; default
  is `data-testid`, and a comma-separated list matches several attributes.
- **Testing Library** — `configure({ testIdAttribute: 'data-testid' })` in the setup file
  (also configurable per fixture/page in some integrations).
- **Cypress** — no built-in test-id query; projects use a custom command or
  `@testing-library/cypress`. Read the repo's selector helper and match it.

If you introduce a new attribute name, update the runner config in the same change, or the
ids you added are invisible to the tests that need them.
