# thedv91-skills

A Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) of skills for code review and React best practices.

## Plugins

| Plugin | Description |
| --- | --- |
| `review-code-change` | Review the diff of the current branch against a target branch against extensible standards (security, performance, business logic, React/Next.js/Node/TypeScript). Read-only git. Invoke with `/review-code-change:review-code-change`, or `/review-code` for the blast-radius flow grounded in real test/typecheck/lint output. |
| `bugfix-pattern-sweep` | Read the diff of a bug fix, infer the root-cause anti-pattern it removed, then sweep the codebase for sibling occurrences of the same defect. Reports and ranks; never edits. |
| `authoring-as-the-user` | Set the standard for text that ships under your name — PR/MR descriptions and review comments, commit messages, tickets, docs. A hedge a tool call could settle is unfinished work, not a caveat: verify what is reachable, report it in measurements, and name only the specific residue that stayed out of reach. |
| `testid-instrumentation` | Add stable `data-testid` attributes serving two jobs at once: e2e selectors that survive refactors, and identity — an inspected DOM node greps straight back to the component that rendered it, with no second attribute. Detects the repo's existing attribute name, naming convention, and test-runner config before editing. Framework-agnostic (React, Vue, Angular, Svelte, Solid, web components, server-side templates). |
| `auto-commit` | Commit tracked changes after a task completes, using Conventional Commits — one commit for a small change, or several grouped by architectural layer for a large one. Commit-only: never stages blindly, never amends, never pushes. Supports `--dry-run`. |
| `file-hooks` | Run project-defined commands on the file Claude just edited. A `PostToolUse` hook dispatches to per-project rules in `.claude/file-hooks.json`, matching the changed file by regex. Shared mechanism, per-project commands. |
| `react-compiler` | Write React components and hooks fully compatible with React Compiler's automatic memoization. |
| `react-effect-event` | Use React's `useEffectEvent` to separate reactive dependencies from non-reactive latest-value reads inside Effects. React 19.2+. |
| `react-spring` | Spring-physics animation with react-spring v9+ — which hook fits which job, the object-vs-function config forms, and the mistakes that silently produce no animation. |

## Install

Add the marketplace, then install the plugins you want:

```shell
/plugin marketplace add thedv91/skills
/plugin install review-code-change@thedv91-skills
/plugin install bugfix-pattern-sweep@thedv91-skills
/plugin install authoring-as-the-user@thedv91-skills
/plugin install testid-instrumentation@thedv91-skills
/plugin install auto-commit@thedv91-skills
/plugin install file-hooks@thedv91-skills
/plugin install react-compiler@thedv91-skills
/plugin install react-effect-event@thedv91-skills
/plugin install react-spring@thedv91-skills
```

Or from the CLI:

```shell
claude plugin marketplace add thedv91/skills
claude plugin install review-code-change@thedv91-skills
```

Update later with `/plugin marketplace update thedv91-skills`.

## Layout

```
.claude-plugin/marketplace.json   # marketplace catalog
plugins/<name>/
  .claude-plugin/plugin.json      # plugin manifest
  skills/<name>/SKILL.md          # the skill
  skills/<name>/references/       # loaded on demand, not upfront
  commands/<name>.md              # slash command, when the plugin ships one
  hooks/hooks.json                # hook wiring, when the plugin ships one
```

## Validate

```shell
claude plugin validate .                       # marketplace.json
claude plugin validate ./plugins/review-code-change   # a plugin manifest + skill frontmatter
```
