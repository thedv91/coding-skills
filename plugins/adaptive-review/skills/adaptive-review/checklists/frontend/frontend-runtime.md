# Frontend runtime — races, lifecycle, async UI — HIGH (runtime-class items capped MEDIUM until observed)

Default severity: **HIGH** — but almost everything here is **runtime-class**
(see `references/standards.md`): reading the code tells you the guard is
missing, not that the race fires. Report at MEDIUM with repro steps in minimal
mode; take it to the browser in advanced mode and report `OBSERVED` at full
severity when it reproduces. The line: a defect present *regardless of
ordering* (an interval with no `clearInterval`, a listener with no `remove`, a
global mutated on an early-return path) is static-class and needs no browser;
a defect that only fires *when* things happen in a particular order (a stale
response overwriting a fresh one, a double submit, a bypassed guard) is
runtime-class even when the missing guard is obvious from the code.

Apply when the diff touches Effects, timers, subscriptions, listeners,
observers, fetches, routing/navigation, optimistic updates, forms that submit,
websockets, storage sync, or any UI state machine. `react.md` owns the hook
mechanics (dep arrays, "you might not need an Effect"); this file owns what
happens *at runtime* when the pieces interact.

## Every Effect exit path is a contract

For each changed Effect, enumerate its exit paths — normal cleanup, early
return, the "already loaded" guard, the error branch — and for each list what
was mutated before it (listener added, timer scheduled, script injected, global
written, DOM node appended, subscription opened) and whether the cleanup undoes
exactly that. StrictMode mounts → unmounts → remounts in dev; if the feature
doubles a request, opens two sockets, or counts twice under StrictMode, the
Effect is missing cleanup or is not idempotent — fix the Effect, never remove
StrictMode.

```tsx
// BAD — early return after a global mutation; cleanup never runs for it
useEffect(() => {
  if (window.__widgetLoaded) return;
  window.__widgetLoaded = true;
  const s = document.createElement('script'); s.src = SRC; document.body.append(s);
}, []);
// GOOD — every mutation has a matching undo on every path
useEffect(() => {
  if (window.__widgetLoaded) return;
  window.__widgetLoaded = true;
  const s = document.createElement('script'); s.src = SRC; document.body.append(s);
  return () => { s.remove(); window.__widgetLoaded = false; };
}, []);
```

## Async work that outlives its trigger

- **Last-to-resolve wins instead of last-to-fire.** A slower earlier request
  resolves after a newer one and overwrites fresh state. Guard with an
  `ignore`/`AbortController` in the cleanup, a request id compared on
  resolve, or the query library's built-in cancellation. Search-as-you-type,
  tab switches, and paginated lists are the usual victims.
- **Setting state after unmount / on a stale closure** — the `.then` of a
  fetch started in a component that navigated away.
- **Overwritten timeouts** never cancelled (`setTimeout` stored in a ref and
  reassigned without `clearTimeout`); debounce/throttle implemented ad hoc
  with a boolean.
- **Promise chains without `finally`** leave `isLoading` stuck `true` on the
  error path; an unhandled rejection surfaces as a console error and a frozen
  spinner.
- **Animation loops / `requestAnimationFrame`** kept running after the UI moved
  on.

## Concurrent interactions

- **Double submit.** A submit handler that can run twice on a double click,
  Enter + click, or a re-render mid-request — the button is not disabled or the
  guard is a `useState` boolean that has not committed yet (use a ref or the
  form's pending state / `useTransition` / `useFormStatus`).
- **Two operations that must be mutually exclusive can overlap** — save while
  a load is in flight, delete while an edit is unsaved. Booleans cannot
  represent a three-state UI; prefer an explicit state (`'idle' | 'saving' |
  'error'`) and a transition function.
- **Optimistic updates without rollback**, or rollback that clobbers a newer
  server value; an optimistic list add that duplicates when the real item
  arrives.
- **Multi-tab / storage sync** — a `storage` event or BroadcastChannel handler
  that mutates state the current tab is mid-editing.

## Navigation and routing

- Guards that block leaving with unsaved changes can be bypassed by
  back/forward or a programmatic `router.push`; a `beforeunload` handler that
  is added but never removed.
- State that should reset on route change (a form, a scroll position, a
  selection) survives via a component that is not remounted — or the reverse: a
  `key`-less list that keeps a row's local state for the wrong item after a
  reorder.
- Deep-link / refresh on the changed route: does the page render from URL state
  alone, or does it assume in-memory state set by a previous screen?
- Focus and scroll after navigation — the new page's heading gets focus /
  scroll resets — where the app already does this elsewhere.

## Data layer semantics (TanStack Query, SWR, RTK Query, Apollo, framework loaders)

- Query keys include every variable the fetch depends on — a missing key part
  serves another user's/page's cached data.
- Mutations invalidate or update the queries they affect; a stale list after
  create/delete is a real, visible bug.
- `staleTime`/`gcTime`/`revalidate` choices match the data's volatility;
  `enabled: false` gates that never turn on; a dependent query that fires with
  `undefined` params.
- Loading / error / empty states are declared **and rendered** — a declared
  `isError` branch that no JSX reads is dead; a list with no empty state shows a
  blank region.
- Suspense boundaries placed so a slow leaf does not blank the whole page;
  error boundaries so a thrown promise/error does not unmount the app.

## Real-world conditions the browser will impose

Advanced mode drives these; minimal mode lists them as repro steps:

- slow network / offline (throttle in the browser tools) — what does the user
  see for 3 seconds?
- expired session mid-flow — where does the 401 land?
- rapid repeat interaction (double click, spam Enter, fast tab switching)
- back/forward after the change, refresh on the deep link
- narrow viewport, zoomed text, reduced-motion preference

## What not to flag

- Framework choice, animation taste, DOM style preferences.
- A missing guard for a race the surrounding architecture already prevents
  (a query library that cancels superseded fetches; a form library that
  disables submit while pending) — name the mitigation and drop it.
- Pulling in a dependency to fix a race that a dozen lines resolve; the
  finding is the race, the fix is usually small.
