# Scope — resolve the target and collect the diff

Owned by Step 1 of `SKILL.md`. Every command here is read-only. The output is
`<REF>` (the ref you compare against), the changed-file list, the diff, and a
set of notes for the report's **Scope & evidence** section.

## 1. Resolve TARGET — before running any diff

TARGET = the branch the user passed (Step 0). If none was passed, **detect the
repo's default branch — do NOT assume `main`** (many repos merge into `dev`,
`develop`, or `master`):

```
git rev-parse --abbrev-ref origin/HEAD   # e.g. "origin/dev" → TARGET = dev
```

If `origin/HEAD` is unset, infer from
`git branch -rl origin/main origin/master origin/dev origin/develop` (prefer
in that order; list the patterns separately — git does not expand `{a,b}`
braces, a single brace pattern silently matches nothing) — and only then fall
back to `main`. Record whether TARGET was user-supplied or auto-detected.

Now pin the ref and stop early on the degenerate cases:

```
git rev-parse --abbrev-ref HEAD
git remote                                   # empty → no remote; skip the fetch
git fetch --quiet || echo "FETCH FAILED — origin refs may be stale"
git rev-parse --verify --quiet origin/<TARGET>
git rev-parse --verify --quiet <TARGET>
```

- **Prefer `origin/<TARGET>` whenever it exists.** A local `main`/`dev` is
  routinely stale; diffing against it replays already-merged commits as if
  they were new and every finding on them is a phantom. Fall back to the local
  ref only when there is no remote-tracking one, and say which you used.
- **Fetch failed** → still prefer `origin/<TARGET>`, but note in Scope &
  evidence that the ref may be stale. Do not abort.
- **No remote configured** (`git remote` prints nothing; the fetch exits 0
  and prints nothing) → there is no `origin/<TARGET>` to prefer; use the local
  ref and write "no remote — compared against local `<TARGET>`" in Scope &
  evidence.
- Neither ref exists → `git branch -a`, ask the user which branch, STOP.
- HEAD == TARGET → nothing to compare, say so, STOP.

Call the ref you settled on `<REF>`.

## 2. Uncommitted and untracked work is NOT in the branch diff

```
git status --short
```

`git diff <REF>...HEAD` sees only **committed** work. Reviewing a stale
snapshot while the user's newest edits sit uncommitted is worse than not
reviewing.

- Clean tree → proceed.
- Dirty tree → tell the user which files, and fold them in: `git diff HEAD`
  (unstaged) and `git diff --cached` (staged). Mark those files "uncommitted"
  in Scope & evidence.
- **Untracked files (`??`) appear in neither diff.** `Read` each untracked
  source file directly, fold it in, mark it "untracked". Skip build output and
  editor droppings — but say you skipped them.

## 3. Pull the diff

```
git diff --stat -M <REF>...HEAD
git log --oneline <REF>..HEAD
```

Then the full diff with renames detected and generated/lock files excluded:

```
git diff -M <REF>...HEAD -- . ':(exclude)pnpm-lock.yaml' ':(exclude)package-lock.json' ':(exclude)yarn.lock' ':(exclude)*.lock' ':(exclude)*.snap' ':(exclude)**/_generated/**' ':(exclude)*.min.*'
```

`-M` matters: without it a moved file reads as a whole-file delete plus add,
burying the few lines that actually changed.

**Large-diff guard.** Read `--stat` first. Past ~3,000 lines, do not dump the
whole diff in one command — pull it per feature/directory
(`git diff -M <REF>...HEAD -- <path>`), starting with the files at the centre
of the business flow. Excluded generated files are noted as present, never
reviewed line by line.

Empty diff and clean tree → report "No changes between the current branch and
`<REF>`" and STOP.

## 4. Target-side drift — the three-dot diff has a blind side

`<REF>...HEAD` diffs from the merge-base, so anything that landed on `<REF>`
*after* this branch diverged is invisible to it — and to the working-tree
reads later. That is where semantic merge conflicts live: a caller added on
the target that still uses the old contract of a function this branch changed
merges cleanly and breaks at runtime.

```
git log --oneline HEAD..<REF> -- <paths touched by this branch>
```

- No output → move on.
- Output → `git diff HEAD...<REF> -- <path>` on each hit, and check the two
  sides against each other: does the target add/alter a consumer, sibling, or
  contract that this branch's change violates (or vice versa)? Flag any such
  interaction as a finding and record the drift check's result.

## 5. Stacked branch — a wrong parent poisons the diff

If this branch was cut from **another unmerged feature branch**, the
merge-base with `<REF>` predates the parent's work, so the diff replays the
parent's commits as if they were this branch's — and you end up blaming
someone else's unmerged work.

Read the `git log --oneline <REF>..HEAD` you already pulled for the tells:
commit clusters referencing a different ticket, another author's unrelated
series, subjects that belong to another feature. When in doubt,
`git branch -a --contains <oldest-suspect-commit>`.

Stacked → don't silently review the union. Tell the user the branch looks
stacked on `<parent>`, review only the commits on top (diff against the
parent tip), or — if the layers can't be separated — label each finding with
its layer. Record the split.

## What Scope & evidence must carry out of this file

- The ref compared against (`origin/<TARGET>` or local fallback), and whether
  TARGET was user-supplied or auto-detected; fetch-failed note if any.
- Uncommitted / untracked files folded in (or skipped).
- Whether the diff was chunked under the large-diff guard, and which excluded
  generated files were present.
- The drift check's result and any stacked-branch split.
