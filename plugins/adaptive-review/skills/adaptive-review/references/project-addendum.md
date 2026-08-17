# The repo addendum — `.claude/review-skills.md`

This skill is project-agnostic. Everything a specific repository knows that a
generic reviewer cannot infer from the diff goes into **one file in that
repo**: `.claude/review-skills.md`. Generate it with this plugin's own
`/adaptive-review:init-review-addendum` command, or write it by hand from the
template below. (The path and shape are deliberately compatible with other
review tools that read a `.claude/review-skills.md` addendum, so a team keeps
one file — never a second, drifting copy — but nothing here depends on those
tools being installed.)

Absent → the review proceeds on bundled criteria alone. Present → it is
**binding** on criteria, and never on process: it may add what to check and
what not to flag; it may not replace the severity scale, the evidence rules, or
the report format (those stay owned by `references/standards.md`).

## What the review does with it

| Section in the addendum | Effect on this skill |
| --- | --- |
| **Default mode** (`minimal` / `advanced`) | Overrides the Step 0 auto-pick when no mode token was passed. An explicit token still wins. |
| **Skills → Always** | Invoke each with the `Skill` tool even when the diff looks unrelated; name it in the report. A listed skill that is not installed is reported as *missing*, never swapped for a lookalike. |
| **Skills → Conditional** | Apply the stated trigger honestly; a trigger that fires is not optional. |
| **Establish intent — repo-specific sources** | Read these in Step 2 before the diff (ticket convention, glossary, ADR path, legacy implementation to check parity against). |
| **Correctness patterns that bite in this codebase** | Highest-yield criteria in the whole review — the repo already paid for them once. Minimal: checked in the last checklist pass. Advanced: handed to the `standards` persona and to any persona whose scope they fall in. |
| **Repo notes for reviewers** | *Do-not-flag* items suppress matching findings silently; CI facts decide what the linter already catches; a local rule that beats a generic skill wins on that point. |
| **Checks to run** (advanced only) | Non-mutating commands the repo wants executed in advanced mode (e.g. `pnpm tsc --noEmit`, `pnpm eslint <files>`, `pnpm vitest run <files>`). Read the script first; if it chains a formatter `--write` or codegen, run the underlying binary directly. Results go under **Observed / ran**. Never a build, codegen, or formatter. |
| **Extra checklists** | Repo-local markdown files (paths) to load alongside the bundled ones — the same shape as `checklists/*/*.md`. Register a trigger per file. |

Where the addendum is more specific than a bundled checklist, it wins on that
criterion. Where it conflicts with the severity scale or report format, the
skill wins — the addendum supplies criteria, not a different report.

## The bar for what belongs in it

Would a competent reviewer who knows the language but not *this* repo get it
wrong without being told? Yes → it belongs. No → leave it out. A bloated
addendum is worse than none: mandatory sections that are 80% filler get
skimmed. Three or four real defect classes mined from the repo's own fix
history beat twelve guesses. Do not copy `CLAUDE.md` rules into it — reference
them; two copies drift.

## Template

English, regardless of the conversation language. Omit sections with nothing
earned — no placeholders.

```markdown
# Review criteria for this repo

Binding addendum for `adaptive-review` (and any compatible reviewer that reads
this file). Names the skills a review here must apply and carries the
repo-specific criteria a general-purpose review cannot know. Reviews are
read-only: everything below is review *criteria*.

## 0. Defaults
- Default mode: advanced   <!-- or minimal; omit to let the reviewer auto-pick -->

## 1. Skills
### Always
| Skill | Why it is mandatory here |
| --- | --- |
### Conditional
| Skill | Trigger |
| --- | --- |

## 2. Establish intent — repo-specific sources
<ticket key convention, glossary/ADR paths, legacy parity targets>

## 3. Correctness patterns that actually bite in this codebase
<each stated as what to check, with the commit or incident it came from>

## 4. Repo notes for reviewers
<CI or its absence; what NOT to flag; which local rule beats a generic skill>

## 5. Checks to run (advanced mode)
- `pnpm tsc --noEmit`
- `pnpm eslint <changed files>`

## 6. Extra checklists
| Path | Trigger |
| --- | --- |
| `docs/review/forms.md` | `src/features/**/*Form.tsx` |
```

## Generating one

`/adaptive-review:init-review-addendum` (bundled with this plugin) surveys the
repo — manifest, CI, its own rules, ticket conventions, launch/check commands,
and the last ~60 fix commits — and proposes an addendum for confirmation
before writing anything. Writing it by hand works just as well, from the same
evidence: never from generic best-practice knowledge the bundled checklists
already carry.
