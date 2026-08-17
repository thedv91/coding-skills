# adaptive-review

Two-mode code review of the current branch's diff against a target branch.
Read-only git; never edits code.

```
/adaptive-review:adaptive-review                 # auto-pick mode, auto-detect target
/adaptive-review:adaptive-review minimal         # checklist walk only
/adaptive-review:adaptive-review advanced develop
```

| | Minimal | Advanced |
| --- | --- | --- |
| Reads | diff + full changed files + checklists | + every consumer in the blast radius |
| Tools | `git` (read-only), `Read`, `Grep` | + codegraph / serena (fallback `rg`), `Agent`, agent-browser |
| Who reviews | one pass per checklist bucket | reviewer agents per persona → verifier agents that try to refute |
| Evidence ceiling | `TRACED` | `OBSERVED` — runtime-class findings reproduced in the real app |

Mode auto-pick: **advanced** when the host exposes `Agent` and codegraph/serena
and the diff touches source; otherwise **minimal**. A repo can set `Default
mode` in its addendum. The choice is always announced.

## Layout

```
commands/init-review-addendum.md  # /adaptive-review:init-review-addendum — generate .claude/review-skills.md
skills/adaptive-review/
  SKILL.md                      # spine: mode → scope → intent → criteria → review → disprove → report
  references/
    scope.md                    # target detection, dirty tree, untracked, drift, stacked branch
    standards.md                # evidence tiers, severity + caps, disprove pass, report template, verdict
    mode-minimal.md
    mode-advanced.md            # blast radius, settled decisions, fast pass, fan-out/fan-in, browser observe
    personas.md                 # reviewer roster for advanced mode
    project-addendum.md         # contract + template for .claude/review-skills.md
  checklists/
    index.md                    # the only trigger → checklist mapping
    core/                       # stack-agnostic: intent-and-correctness, user-perspective, security,
                                #   performance, code-health, tests, dependencies
    frontend/                   # typescript, react, frontend-runtime, ui-a11y-i18n, nextjs
```

## Extending

- **New stack** — add `checklists/<stack>/*.md` + rows in `checklists/index.md`;
  optionally a persona section in `references/personas.md`.
- **Specific repo** — write `.claude/review-skills.md`, or generate it with the
  bundled `/adaptive-review:init-review-addendum` command: mandatory skills,
  repo intent sources, defect classes that bite here, do-not-flag notes,
  default mode, checks to run in advanced mode, extra checklists. Template in
  `references/project-addendum.md`.

Self-contained: everything the review needs ships here. External pieces are
optional tools the host may expose (codegraph, serena, `Agent`, agent-browser,
`gh`/`glab`) and optional installed tech-stack skills; missing ones narrow the
evidence, never block the review.

## Lineage

Combines the diff-collection and evidence rules of `/review-branch` /
`review-code-change`, the checklist library of `review-code-change`, the
persona roster / confidence anchors / verifier pass of EveryInc's
`ce-code-review`, the confidence rubric of the official `code-review` plugin,
the two-axis (standards vs spec) idea from mattpocock's `code-review`, and the
approval standard / structural remedies of `code-review-and-quality`.
