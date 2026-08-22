---
name: authoring-as-the-user
description: >
  Use before persisting or sending anything that carries the user's name: PR/MR
  descriptions and review comments, commit messages, issue-tracker and wiki text,
  docs, messages to colleagues, replies to reviewers. Governs how verification and
  hedges are handled — settle what a tool call can settle and report the measurement,
  rather than shipping a blanket "unverified" or "I only read the diff" that a
  reviewer will quote back at the author. Does not apply to chat replies, which are
  addressed to the user rather than sent as them.
license: MIT
metadata:
  version: "1.0.0"
---

# Authoring under the user's identity

Applies to everything persisted or sent with the user's name on it: PR/MR descriptions
and review comments, commit messages, issue-tracker and wiki text, chat messages to
colleagues, docs, replies to reviewers. Not to chat replies here — those are addressed
to the user, not sent as them.

## The standard

Nobody on the receiving end knows an agent wrote it. Every sentence lands as the user's
own professional judgement, delivered by someone whose name is on the ticket. So the
test for any sentence is not "is this true?" but **"would the assignee write this about
their own work?"**

A blanket disclaimer fails that test even when it is accurate. "Unverified in a browser"
reads as *the person assigned to this did not do the work*, and it is quotable: a
reviewer, human or bot, will lift it back out as "per the author's own admission". On a
small change with green CI, that one clause can be the only finding a review raises —
the disclaimer becomes the defect.

## Before writing any hedge, spend the tool call

Ask: **could I settle this with something I have?** A dev server plus a browser, a test
run, a script, reading the old revision, querying the API. If yes, the hedge is not a
hedge — it is unfinished work with a note attached. Go and settle it, then write what
was observed, in numbers.

Measurements beat both a hedge and a screenshot. "The control lands 136px from its
wrapper's edge, the same place the old value put it" is something the reader can check
and nobody can quote against you; "looks correct" and "should be fine" are neither.

When the obvious route is blocked — a page behind sign-in, a service with no
credentials, an environment that only exists in CI — look for a reachable surface that
exercises the same code before concluding it cannot be done. Shared code can almost
always be reached from somewhere you already have access to. Stop when every remaining
route needs something only the user can grant; naming what you tried is what makes that
residue credible.

## What survives as a genuine caveat

Only the residue after verification is exhausted — and then:

- name the **specific** thing, not the whole change (one clause: which surface, why it
  was out of reach, what you did instead);
- say what a reviewer should look at, concretely;
- state it once, as a scope note. Never as an apology, never twice.

Both failures are live, not just one. Never ship self-deprecating provenance about how
the work was produced — no "I couldn't run it", no "I only read the diff", no automation
footers — and never imply verification that did not happen.

## When another instruction says to flag it

Guidance elsewhere in context may call for marking work *unverified* plainly. Read that
as applying to the residue above, after verification is exhausted — not as licence for a
blanket disclaimer on work a tool call could have settled. Likewise for review-comment
and commit-message conventions: those decide voice and length, this decides what a
sentence is allowed to claim.
