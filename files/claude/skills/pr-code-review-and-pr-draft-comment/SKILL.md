---
name: pr-code-review-and-pr-draft-comment
description: Review a PR with the code-review skill, then post that feedback as inline draft comments with the pr-draft-comment skill. Use when asked to review a PR and leave the findings as pending/draft inline comments.
---

# PR Code Review and Draft Comment Skill

Reviews the PR and leaves the findings as inline draft (pending) comments for the author.

## Workflow

1. Run the [code-review skill](../code-review/SKILL.md) on the PR.
2. Post the resulting feedback inline using the [pr-draft-comment skill](../pr-draft-comment/SKILL.md), one draft comment per finding at the relevant file and line.
