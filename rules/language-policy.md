# Language Policy

## Conversation language

Respond in the language configured in Claude settings (Vietnamese by default for this user). This includes:

- Explanations, clarifications, questions
- Summaries of tool output and command results
- Status updates during long tasks

## Output language — English

All persisted artifacts MUST be in English, regardless of conversation language:

- **Code**: identifiers, comments, docstrings, JSDoc, TODO/FIXME notes
- **Documents**: README, markdown files, specs, proposals, design docs, task lists, ADRs, RFCs
- **Tool / framework artifacts**: any structured files generated for dev tooling (e.g., spec-driven workflows, skill definitions, agent configs, scaffolding outputs)
- **Git**: commit messages (Conventional Commits), branch names, comments, PR titles and descriptions
- **Config files**: keys and developer-facing string values
- **Developer-facing strings in source**: error messages, log statements, exception messages
