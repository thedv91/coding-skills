---
name: react-compiler
description: >
  Write React components and hooks that are fully compatible with React Compiler's
  automatic memoization. **Top rule: never put `try/catch` (or `try/finally`) inside a
  component body or custom hook body — the compiler cannot reason across exception
  control flow and silently bails out of memoizing the whole function. Extract it to a
  module-scope helper.** Also: components stay pure, props/state are never mutated,
  side effects stay outside render, hooks stay at the top level, and new code leans on
  compiler-handled memoization instead of reaching for useMemo/useCallback by reflex.
  Apply when writing or editing any component or custom hook, and when reviewing hooks,
  effects, memoization, render-time logic, or state before enabling the compiler.
  Stack: React 17+, React 18+, React 19+.
license: MIT
metadata:
  version: "1.1.0"
---

# react-compiler

React Compiler is a **build-time tool** that automatically memoizes your components
and hooks — it replaces manual `useMemo`, `useCallback`, and `React.memo`. For it to
work safely, your code must follow the **Rules of React** exactly. Violating them
causes the compiler to silently skip optimization or produce incorrect behavior.

## What the compiler does (and does not do)

- **Does**: memoizes React components and hooks automatically, skips unnecessary
  re-renders, caches expensive calculations inside render.
- **Does not**: memoize arbitrary helper functions called from components; memoization
  is per-component, not shared across the tree.
- **Result**: new code rarely needs hand-written `useMemo`/`useCallback` for
  performance — the compiler's inference is usually as precise or more precise.
  Existing manual memoization is not something to sweep out; see
  [Manual memoization alongside the compiler](#manual-memoization-alongside-the-compiler).

## Bail-outs are silent

When the compiler meets code it cannot prove safe, it **skips optimizing that scope**
rather than emitting wrong code. There is no build error and no warning — the component
just quietly stops being memoized. Assume nothing; verify with the tools in
[Detection](#detection).

## Hard rules — Rules of React

Break any rule and the compiler will either bail out of optimizing that component or
produce a bug.

### 1. Components and hooks must be pure

Every component must return the same output given the same inputs (props, state,
context). React may call your component multiple times.

```tsx
// ❌ impure — side effect during render
function Counter({ id }: { id: string }) {
  fetch(`/api/log?id=${id}`); // fires on every render
  return <div>{id}</div>;
}

// ✅ pure render, side effect moved to useEffect
function Counter({ id }: { id: string }) {
  useEffect(() => { fetch(`/api/log?id=${id}`); }, [id]);
  return <div>{id}</div>;
}
```

### 2. Props and state are immutable — never mutate them

```tsx
// ❌ mutating props
function TagList({ tags }: { tags: string[] }) {
  tags.push("extra"); // corrupts the caller's array
  return <ul>{tags.map(t => <li key={t}>{t}</li>)}</ul>;
}

// ✅ derive a new value
function TagList({ tags }: { tags: string[] }) {
  const all = [...tags, "extra"];
  return <ul>{all.map(t => <li key={t}>{t}</li>)}</ul>;
}
```

```tsx
// ❌ mutating state directly
function Form() {
  const [user, setUser] = useState({ name: "", age: 0 });
  const handleChange = () => {
    user.name = "Alice"; // mutation — React won't see this
    setUser(user);
  };
}

// ✅ create a new object
const handleChange = () => setUser({ ...user, name: "Alice" });
```

### 3. Hook return values and arguments are immutable

Values returned from or passed into hooks must not be mutated after the call.

```tsx
// ❌ mutating a value passed to a hook
const [items, setItems] = useState<string[]>([]);
items.push("new"); // mutates state — invisible to React

// ✅
setItems(prev => [...prev, "new"]);
```

### 4. JSX values are immutable after use

Once a value appears in JSX, don't mutate it.

```tsx
// ❌
const config = { label: "Submit" };
const btn = <Button config={config} />;
config.label = "Loading"; // too late — config is already in JSX

// ✅
const btn = <Button config={{ label: "Submit" }} />;
// or mutate before the JSX line
config.label = "Loading";
const btn = <Button config={config} />;
```

### 5. Call hooks only at the top level

Never inside conditions, loops, early returns, or nested/non-React functions.

```tsx
// ❌
function Profile({ isAdmin }: { isAdmin: boolean }) {
  if (isAdmin) {
    const [role, setRole] = useState("admin"); // conditional hook
  }
}

// ✅
function Profile({ isAdmin }: { isAdmin: boolean }) {
  const [role, setRole] = useState(isAdmin ? "admin" : "viewer");
}
```

### 6. Never call component functions directly, never pass hooks as values

Always render via JSX, never as a plain function call. Hooks are called, not passed
around — a hook stored in a variable or handed to another function is invisible to
both the linter and the compiler.

```tsx
// ❌ — bypasses all of React's rendering rules
const content = MyComponent({ title });
// ❌ — hook as a value
const useIt = flag ? useFoo : useBar;

// ✅
const content = <MyComponent title={title} />;
```

### 7. Declare every effect dependency

Don't suppress `exhaustive-deps`. When a value must be read at its latest without
re-triggering the effect, extract that read into `useEffectEvent` rather than lying
about the dependency array.

### 8. Don't read `ref.current` during render

Refs are mutable and invisible to the compiler's dependency analysis. Read and write
them only in effects and event handlers.

### 9. Don't call `setState` unconditionally during render

That's an infinite render loop. Derive the value inline instead, or sync via an effect
if it genuinely cannot be derived.

## Concrete anti-patterns

Three shapes cause most real bail-outs: `try/catch` in a component or hook body (the
hard one), `useMemo([])` wrapping an environment read, and inline imperative
orchestration inside a hook. Each is written out with its rewrite in
[`references/anti-patterns.md`](references/anti-patterns.md), together with the
upstream links — load it when you hit one, or when reviewing a file for bail-outs.

## Authorship conventions

- **In new code, don't reach for `useMemo` / `useCallback` / `React.memo` by reflex.**
  Write the plain version first and let the compiler memoize it. Add them deliberately
  when there's a reason: a value that needs stable identity for an external consumer
  (a library hook's effect dep, a non-React subscriber), or a hot path where profiling
  shows the compiler missed something.
- **Prefer module-scope pure helpers for imperative logic** — see
  [`references/anti-patterns.md`](references/anti-patterns.md).
- **Destructure stable primitives out of library-hook results** instead of closing over
  the whole object:

  ```tsx
  const { data } = useQuery(...);   // ✅ stable
  useEffect(() => doThing(data), [data]);
  ```

## Manual memoization alongside the compiler

Existing `useMemo` / `useCallback` / `React.memo` is **not a violation** and is not
something to sweep out of a codebase. The compiler reads it, tries to preserve the
guarantees it provides, and generally leaves correct memoization alone. Much of it
also carries intent the compiler can't infer — a stable identity some external
consumer relies on, a deliberately narrowed dependency, a documented hot path. Leave
it be unless you know why it's there.

What matters for compiler compatibility:

- **A hand-written memo whose dependencies don't match what the compiler infers** —
  a missing dep, a suppressed `exhaustive-deps`, a dep list that silently lies — is a
  case the compiler can't validate, so it bails out of that component. The fix is the
  wrong dependency, not the `useMemo`.
- **A memo defeated by something inside it** still costs a render. Classic shape: a
  `useCallback` that an inline arrow in `.map()` re-wraps every render, so the stable
  identity never reaches the child. Worth noticing when you're already in the file —
  but it's a correctness/perf observation, not a compiler rule.
- **Memoization is not the compiler's business to verify beyond that.** If a component
  is memoized correctly by hand and by the compiler, both are fine.

## Detection

| Method                                           | When                                                            |
| ------------------------------------------------ | --------------------------------------------------------------- |
| `eslint-plugin-react-hooks` v6+                  | Authorship — inline squiggles; compiler rules are merged into this plugin (the standalone `eslint-plugin-react-compiler` is deprecated) |
| React DevTools ✨ badge                          | Runtime — components the compiler memoized are marked with ✨   |
| `npx react-compiler-healthcheck --src "path/**"` | CI / pre-commit — static scan, file-scoped                       |

The linter does not catch every bail-out — notably it can stay silent on the
`try/catch` case. Treat the ✨ badge and the healthcheck as the ground truth.

## Opt-out: "use no memo"

Add the directive at the top of a component or hook to tell the compiler to skip it.
Use this as a **temporary escape hatch** while fixing violations, not permanently —
every use is code the compiler can't help, so justify it in a comment.

```tsx
function BrokenComponent() {
  "use no memo"; // compiler skips this component entirely
  // ... fix Rules of React violations here, then remove the directive
}
```

For gradual rollout, `compilationMode: 'annotation'` in the compiler config means
only functions with `"use memo"` are compiled — the inverse of opt-out.

## What the compiler cannot optimize

- **Arbitrary helper functions** that are not components or hooks.
- **Expensive computations shared across components** — memoization is not shared;
  move those outside React (module-level cache, server-side, etc.).

## Checklist when writing a component

1. Any `try/catch` or `try/finally` in the component/hook body? Extract it to
   module scope — this is the #1 silent bail-out.
2. Does every render path return the same output for the same inputs?
3. Are props, state, and hook return values treated as read-only?
4. Are all mutations done on locally created values, not on inputs?
5. Are hooks called unconditionally at the top level, and never passed as values?
6. Are all side effects inside `useEffect`, event handlers, or async functions —
   not during render? No `ref.current` reads or unconditional `setState` in render?
7. Are all effect deps declared, with `useEffectEvent` instead of a suppression?
8. If you added `useMemo`/`useCallback`/`React.memo`, can you name the reason?
   If it was reflex, try the plain version — the compiler likely covers it.
9. Any `"use no memo"` left in place? Remove once violations are fixed.
