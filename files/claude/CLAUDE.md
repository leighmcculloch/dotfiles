# Claude

## Planning

If `mcp-gemini` is connected, chat to Gemini, ask it to come up with a plan, ask it questions and iterate on the plan with Gemini until it is ready to implement. Chat to Gemini in follow up as the plan needs to evolve. Chat to Gemini and ask it to provide reviews of the implementation. 

## Bash Commands

Run all commands with the `sandbox --allow-file-write . -- ` prefix.

## Git Branch

When starting work on a new issue, always create a new branch first. Use a concise, kebab-case branch name that describes the changes (max 5 words).

When needing to update a branch, if the branch is not pushed rebasing is fine. If the branch is pushed to a remote, never rebase, only merge.

## Git Commit

Commit after every change immediately, without asking for confirmation for what to use as the commit message. Use a concise, commit message that says in present tense with imperative mood what has changed without saying why (max 50 characters). Do not use convention commit format. Start the commit message with a lower case letter and do not end with a full stop. Avoid generic phrases.

## Pull Requests

When asked to open a pull request, only ever open draft pull requests.

If the repository has no pull request template, use the following format:

Use a concise pull request title (max 50 characters) and description, where the description is separated into two sections. Be direct, eliminate filler words and phrases. Think like a journalist.

The first section is under the heading "### What" and describes what has changed. Use imperative mood. Do not lead with a plural. e.g. Upgrade vs upgrades. Enable vs enables. Add vs adds. The second section is under the heading "### Why" and describes why the change is being made. Be concise with why, and avoid generic statements.

Start the title with a capital letter but do not end with a full stop. Use full sentences for what and why. Avoid generic phrases.

After the pull request has been opened, monitor the GitHub Actions runs and fix any failures before finishing.
