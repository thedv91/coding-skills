# Tests — MEDIUM

Default severity: **MEDIUM** (a bug fix shipped with no test that would have
caught it, or a test that only passes because of harness ordering, may be
**HIGH**). Apply when the diff adds/modifies tests, or changes behaviour that
existing tests cover or should cover. Production-file presence alone is not a
trigger — a rename or a comment change owes no test.

The review never claims a test passes or fails unless it actually ran (advanced
mode, only when the repo addendum lists the command). Otherwise it *reads* the
tests and judges whether they prove anything.

## Do the tests prove anything?

- **Real assertions.** Concrete expected values, not snapshot-only, not
  "renders without crashing", not "does not throw". A snapshot-only test locks
  in whatever the code does, including the bug.
- **The subject is actually exercised.** A test that mocks away the very unit it
  claims to test proves nothing — compare what is mocked against what is
  asserted. Mocking the network is fine; mocking the hook under test is not.
- **A bug fix carries a prove-it test** that fails on the old code and passes
  on the new. If the fix has no test that would have caught the original bug,
  say so — that is the finding, not "add more tests".
- **The edge cases the change introduced** (empty, null, boundary, error path,
  cancelled/unmounted, slow response) are covered, or the test is happy-path
  only.
- **Behaviour, not implementation.** Tests that assert internal state, call
  counts of private helpers, or DOM structure that is not the contract will
  break on the next harmless refactor and prove nothing meanwhile.

## Frontend-specific traps

- `act()` warnings silenced instead of resolved; a `waitFor` with no assertion
  inside; `await` missing on an async `findBy*`.
- Fake timers left installed across tests; a test that passes only because a
  sibling ran first (shared module state, un-reset store, leaked mock).
- A test of an async race (stale response overwriting fresh state) run in
  jsdom with fake timers is a *hypothesis* about production ordering, not a
  proof — say so; do not promote a race finding on its evidence.
- Queries by test id where an accessible role/name query would also assert the
  a11y contract (`getByRole('button', { name: /save/i })`).
- Storybook/visual snapshots updated without a reason in the commit —
  intentional design change or hidden regression?

## Coverage of the change

- New behaviour has unit / integration / e2e tests as appropriate for the
  project (look at how neighbouring features are tested; do not invent a test
  layer the project does not have).
- Changed public functions/components keep their existing tests meaningful —
  a test edited to match the new output should be checked for whether the new
  output is actually right, not just green.
- Missing coverage for important new logic is **one umbrella finding per
  subsystem**, not one finding per case; narrower gaps go into a single
  "testing gaps" note.

## What not to flag

- Coverage percentages, test file naming, describe/it wording.
- Missing tests for trivial glue (a re-export, a prop passthrough).
- The absence of a test layer the project has visibly chosen not to have.
