# UI: accessibility, forms, responsive layout, i18n — HIGH / MEDIUM

Default severity: **HIGH** for a keyboard trap, an unlabelled control, a form
that cannot be submitted or whose errors are invisible to assistive tech, or a
layout that breaks the primary flow at a supported viewport; **MEDIUM** for the
rest. Apply when the diff touches markup, components that render UI, forms,
styles/CSS/Tailwind classes, or user-facing strings.

Judge as the user who is not the author: keyboard-only, screen reader, 360px
wide, 200% zoom, another locale. Concrete failure, not a WCAG citation, is the
finding. `react.md` has the short a11y list for component code; this file is
the full one.

## Semantics and names

- Native elements first: `<button>`, `<a href>`, `<input>`, `<select>`,
  `<label>`, `<dialog>`, `<nav>`, `<main>`, headings in order. A `<div onClick>`
  as a button needs `role`, `tabIndex`, Enter/Space handling — strictly more
  code than `<button>` and still worse.
- Every interactive element has an accessible name: visible text, an
  associated `<label>`, `aria-label`, or `aria-labelledby`. Icon-only buttons
  are the usual miss.
- `<a>` navigates, `<button>` acts. An `<a>` without `href`, or a link that only
  triggers JS, is neither keyboard-reachable nor announced correctly.
- Images: meaningful `alt`, or `alt=""` for decorative; SVG icons `aria-hidden`
  unless they carry meaning.
- Heading levels don't skip; landmarks exist once (`main`, `nav`, `banner`).
- ARIA only where native semantics cannot do it; a wrong `role` is worse than
  none. `aria-*` values reference ids that exist.

## Keyboard and focus

- Reachable in a sensible order with Tab; operable with Enter/Space/arrows as
  the pattern demands (menus, tabs, listboxes follow the WAI-ARIA pattern
  keys).
- Focus visible — no `outline: none` without a replacement `:focus-visible`
  style.
- Focus **managed**: a dialog moves focus in and restores it on close; a route
  change moves focus to the new content/heading; a deleted item's focus lands
  somewhere sensible, not on `<body>`; a toast does not steal focus.
- Focus **trapped** inside a modal while open, and never trapped elsewhere.
- Escape closes overlays; clicking outside matches the project's convention.

## Forms

- Each control has a label associated by `for`/`id` or wrapping; placeholder
  is not the label.
- Required/invalid state conveyed to AT (`aria-required`, `aria-invalid`,
  `aria-describedby` → the error message), not colour alone.
- Errors appear next to the field and are announced (live region or focus
  moved to the first error on submit); a summary for long forms.
- Enter submits; the submit button reflects pending state; disabled-while-
  pending or otherwise guarded against double submit (see
  `frontend-runtime.md`).
- Autocomplete tokens on identity/address/payment fields where the project
  uses them; input types (`email`, `tel`, `inputMode="numeric"`) so mobile
  keyboards match.

## Colour, motion, and content

- Meaning never carried by colour alone (status dots get text/icon; links in
  body text are distinguishable).
- Contrast plausible for text and essential UI (flag obvious low-contrast grey
  on white; leave exact ratios to tooling).
- Motion respects `prefers-reduced-motion` where the project already does;
  nothing flashes.
- Live updates (toasts, counters, chat) use `aria-live` at the right politeness;
  not everything is `assertive`.

## Responsive layout and styles

- The change survives 360px width, 200% zoom, long/translated text, and an
  overflowing name — no clipped buttons, no horizontal scroll on the page body,
  wide content scrolls in its own container.
- Touch targets ≥ ~44px on mobile surfaces where the project targets touch.
- Fixed heights on text containers, `white-space: nowrap` on user content,
  `overflow: hidden` that hides focus rings or error messages.
- Layout shift: images/media with dimensions or aspect-ratio; skeletons the
  same size as the content they replace.
- Design-system usage: the project's tokens/components/Tailwind scale rather
  than one-off magic values, when the neighbours use them; dark mode / theming
  handled where the app supports it (hard-coded `#fff`).
- CSS specificity or `!important` escalations that fight the design system;
  global styles leaked from a component.

## i18n and formatting

Only in a project that localises — look at how neighbouring components emit
text. A project with no i18n layer → skip this section; do not invent the
requirement.

- No hard-coded user-facing literals; strings go through the project's
  mechanism with stable keys following its naming convention.
- Interpolation and plurals through the library (`t('items', { count })`), not
  string concatenation — word order and plural rules differ per locale.
- Dates, numbers, currencies via the project's locale utilities / `Intl`, never
  `toString`/`toFixed` for display.
- Layout not broken by 30–50% longer German/Finnish or by RTL where supported;
  no text baked into images.
- New keys added to every locale file the project keeps in sync (or its
  fallback rule documented) — a missing key renders as the raw key.

## What not to flag

- Pixel taste, spacing opinions, colour choices within the design system.
- An a11y standard the project has visibly not adopted anywhere (say so once as
  a note, not per line).
- i18n in a project that does not localise.
- Anything `eslint-plugin-jsx-a11y` (when configured) already reports.
