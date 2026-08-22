# React Compiler anti-patterns, ranked by how often they slip in

Loaded on demand from `SKILL.md`. Each entry gives the shape that bails out, why the
compiler cannot handle it, and the rewrite.

### #1 — `try / catch` inside a component or custom hook body (HARD bail-out)

**This is the single biggest cause of silent bail-outs.** The compiler's static analysis
cannot safely memoize across exception control flow, so the moment it sees a
`try { … } catch { … }` (or `try { … } finally { … }`) inside a component body or custom
hook body, it **skips memoization for the entire function** — no error, no lint squiggle
in many setups, just zero benefit. It propagates: a bailed-out hook typically takes its
caller components down with it.

The fix is always the same: **move the `try/catch` into a module-scope helper** and let
the hook/component call the helper. The compiler then sees a plain call site and can
memoize freely.

```tsx
// ❌ try/catch in hook body → compiler bails out on useCountryCode AND on any
//    caller component that uses it
export function useCountryCode(): string {
  return useMemo(() => {
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      return getCountryForTimezone(tz)?.id ?? "default";
    } catch {
      return "default";
    }
  }, []);
}

// ✅ try/catch lives in a module-scope helper; hook body is a single return.
//    Note: useMemo is also dropped — the compiler memoizes the call automatically.
function detectCountryCode(): string {
  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return getCountryForTimezone(tz)?.id ?? "default";
  } catch {
    return "default";
  }
}

export function useCountryCode(): string {
  return detectCountryCode();
}
```

**Where `try/catch` is fine**: inside module-scope helpers, inside event handlers
(already off the render path), and inside an effect callback that is a single inline
arrow with no surrounding render-path scope. Anything else — including `try/finally`
used for cleanup orchestration — extract to module scope.

### #2 — `useMemo([])` wrapping an environment read

A hook reads a browser global (timezone, locale, `navigator.*`, `matchMedia`, …) and
wraps it in `useMemo` with `[]` to "compute once". The impure read is the problem, not
the `useMemo`: lift it into a module-scope helper — same fix as #1. Once the hook body
is a trivial pure call, the `[]` memo has nothing left to do and can go with it.

### #3 — Inline imperative orchestration inside a hook

Async sequences, retry loops, cleanup chains — move the body into a module-scope helper
that receives what it needs from the hook, e.g.
`executeAction(params, { setError, setIsLoading })`. Hooks stay thin (state + wiring),
which is both easier for the compiler to reason about and easier to unit-test. See
`detectCountryCode` under #1 for the minimal shape.


## Reference

- React Compiler overview: https://react.dev/learn/react-compiler
- Rules of React: https://react.dev/reference/rules
- Incremental adoption: https://react.dev/learn/react-compiler/incremental-adoption
- try/catch silent bail-out: https://github.com/facebook/react/issues/35644
