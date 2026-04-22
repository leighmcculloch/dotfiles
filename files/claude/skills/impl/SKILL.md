---
name: impl
description: Implement something, then iterate with commit and review until the review has no suggestions.
argument-hint: <what to implement>
---

# Implement

Use an AGENT TEAM:

Implement what is described in `$ARGUMENTS`. (1-2x Agents: Senior Software Engineer(s))

Then repeat the following loop:

1. Run /commit.
2. Run /review on the commit just made. (2x Agents: Pragmatic Software Engineer Reviewer, Senior Software Engineer Reviewer)
3. If the review identifies any issues, concerns, or suggestions, address all of them, then go back to step 1. (Agent: Senior Software Engineer)
4. If the review is clean (SOUND verdict, no gaps, no similar issues, no recommendations), stop.

## Rules

- ALWAYS use a different agent for the review compared to the implementation. ALWAYS use at least two reviewers. If reviewers do not agree, ask a third reviewer to evaluate the opinions and decide.
- Do not loop more than 10 times. If after 10 iterations the review still has suggestions, stop and report the remaining items to the user.
- Each iteration should only address issues raised by the most recent review. Do not re-introduce changes that were intentionally reverted or dropped.
- If a review finding is subjective or debatable, use your best judgment. Do not loop forever on style disagreements.
- Be pragmatic. Act like a staff engineer who cares a lot about the outcome, and not polishing the turd, or engineering excellence for the sake of engineering excellence.
