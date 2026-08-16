# Test Fix Policy

## Test fails right after a code change

If a test breaks immediately after an intentional-looking code change (a
staged diff, a recent commit, or an edit made earlier in the same session),
the default fix is to **update the test to assert the new, correct
behavior** — not to revert the code to satisfy the old assertions.

Before touching either side:

- Recompute what the new code actually produces for the failing case — trace
  it, don't assume from the old test's expectations.
- Treat the code change as intentional by default when it looks like part of
  the task/ticket already in progress, not an obvious typo.

Only revert the code instead if:

- There's a clear, demonstrable bug (a case with no plausible intended use —
  e.g. a value that's always `undefined`/`null` with no fallback and no
  sensible output).
- The user confirms the code change itself was a mistake.

If it's genuinely ambiguous which side (code or test) reflects the intended
behavior, don't guess and silently pick one — ask the user first.
