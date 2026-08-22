---
name: react-spring
description: >
  Expert guidance for the react-spring animation library (v9+, @react-spring/web),
  focused on its full hooks API. Apply whenever the user works with react-spring or
  mentions useSpring, useSprings, useTrail, useTransition, useChain, useSpringRef, the
  `animated` component, `to()` interpolation, or spring `config` — and more broadly for
  any spring-physics / mount-unmount / staggered / sequenced animation task in React,
  even when react-spring is not named explicitly. Covers the object-vs-function config
  forms, which hook fits which job, the imperative `api.start`/`api.stop` pattern, and
  the mistakes that silently produce no animation; per-hook signatures load on demand
  from `references/hooks.md`. Stack: React 16.8+, @react-spring/web v9+.
license: MIT
metadata:
  version: "1.0.0"
---
# react-spring (v9+, @react-spring/web)

react-spring animates with **spring physics** rather than fixed-duration easing: you
declare a target and the library computes a natural, interruptible motion toward it.
The v9 API is **hooks-first** and every hook shares the same mental model — a *config*
(where to animate from/to and how) produces *animated values* you spread onto an
`animated` element.

> Import everything from `@react-spring/web` (the DOM target). Native/three/konva
> targets exist but share the same hook signatures.

## The two config forms — learn this once, it applies to every hook

Every animation hook accepts its config in one of two shapes. The shape you pick
decides what the hook returns and how you drive the animation.

- **Object form** — `useSpring({ ... })`. Declarative. The animation runs on mount and
  re-runs whenever the passed values change. Returns **only the animated values**.
- **Function form** — `useSpring(() => ({ ... }), deps?)`. Returns a tuple
  `[values, api]` where `api` is a [`SpringRef`](references/hooks.md)
  for firing updates imperatively (in event handlers, effects, etc.). The optional
  `deps` array re-creates the config when a dependency changes, like `useMemo` deps.

Rule of thumb: reach for the **function form whenever a user interaction or external
event should trigger the animation**; use the **object form for animations that simply
follow render state**.

## `animated` — the component that receives spring values

Spring values are not plain numbers; they are live animated objects. Only an
`animated` element can read them without re-rendering React on every frame. Animating
a plain `<div>` with them silently does nothing.

```tsx
import { animated } from '@react-spring/web'

<animated.div style={styles} />        // built-in DOM elements: animated.<tag>
```

Wrap a custom component so it can forward the animated `style`/props:

```tsx
const AnimatedCard = animated(Card)    // Card must forward the props it receives
```

## Which hook for which job

| Situation | Hook |
| --- | --- |
| One element, one set of values | `useSpring` |
| N elements, each with **its own independent** target | `useSprings` |
| N elements that should **follow each other** with a stagger | `useTrail` |
| Items **entering / leaving** a list or a mount boundary | `useTransition` |
| Several animations that must run **in sequence** | `useChain` + `useSpringRef` |
| Fire or stop an animation from an event handler or effect | function form's `api` |

Signatures, both config forms, and worked usage for each of these live in
[`references/hooks.md`](references/hooks.md) — load it when you need the hook you
picked, not upfront. `to()` interpolation and the `config` physics presets are in
there too.

## Common mistakes

- **Animating a plain element.** Spring values must land on `animated.div` (or
  `animated(Component)`). A normal `<div style={styles}>` won't animate — nothing errors,
  it just sits still.
- **Mutating spring values or calling `.start()` on the values object.** Never reassign
  a spring value or push updates onto the returned values. Drive changes through the
  `api` from the function form (`api.start(...)`), or by changing the object-form config.
- **Missing `keys` in `useTransition`.** Without a stable `keys`, react-spring can't tell
  which items are the same across renders, so enter/leave animations misfire on reorder.
  Pass `keys: item => item.id` (or rely on stable primitives).
- **Calling a hook inside `.map()` for a list.** Hooks must run at the top level. Use
  `useSprings`/`useTrail`/`useTransition` with a `count` or data array instead of looping.
- **Expecting `useChain` to fire hooks that already ran.** Chained hooks must be wired
  with `ref` so they don't self-start; otherwise they animate immediately and `useChain`
  has nothing to sequence.
- **Reading a spring value as a number.** `styles.x` is an animated object, not a number.
  To compute from it, go through `.to(...)` / `to(...)`, not arithmetic.

## Reference

- useSpring: https://www.react-spring.dev/docs/components/use-spring
- useSprings: https://www.react-spring.dev/docs/components/use-springs
- useTrail: https://www.react-spring.dev/docs/components/use-trail
- useTransition: https://www.react-spring.dev/docs/components/use-transition
- useChain: https://www.react-spring.dev/docs/components/use-chain
- SpringRef / imperative api: https://www.react-spring.dev/docs/advanced/spring-ref
- Interpolation `to()`: https://www.react-spring.dev/docs/advanced/interpolation
- Config & presets: https://www.react-spring.dev/docs/advanced/config
