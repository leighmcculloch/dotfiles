---
name: impl
description: Implement something, then iterate with commit and review until the review has no suggestions.
argument-hint: <what to implement>
---

# Implement

Implement what is described in `$ARGUMENTS`.

Then repeat the following loop:

1. Run /commit.
2. Run /review on the commit just made.
3. If the review identifies any issues, concerns, or suggestions, address all of them, then go back to step 1.
4. If the review is clean (SOUND verdict, no gaps, no similar issues, no recommendations), stop.

## Rules

- Do not loop more than 10 times. If after 10 iterations the review still has suggestions, stop and report the remaining items to the user.
- Each iteration should only address issues raised by the most recent review. Do not re-introduce changes that were intentionally reverted or dropped.
- If a review finding is subjective or debatable, use your best judgment. Do not loop forever on style disagreements.
