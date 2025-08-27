# Claude

## Planning

Come up with a plan. Ask questions, and iterate on the plan, until it is well formed. Self review the plan and implementation during implementation.

## Git Branch

When starting work, if the current branch is 'main' or 'master', create a new branch first. Use a concise, kebab-case branch name that describes the changes (max 5 words).

Never rebase. Never rewrite history.

## Git Commit

Commit after every change, immediately, without asking for confirmation for what to use as the commit message. Use a concise, commit message that says in present tense with imperative mood what has changed without saying why (max 50 characters). Do not use convention commit format. Start the commit message with a lower case letter and do not end with a full stop. Avoid generic phrases. If code is being moved along with functionality being changed or added, focus on summarising the new or changed functionality, not the refactor.

## Testing

Always add tests. Find existing tests and add new tests alongside. Review related tests and use the same patterns rather than new patterns.

Always run all tests and a build before assuming it works.

## Pull Requests

When asked to open a pull request, only ever open draft pull requests.

Use the following format:

Use a concise pull request title (max 50 characters) and description, where the description is separated into two sections. Be direct, eliminate filler words and phrases. Think like a journalist.

The first section is under the heading "### What" and describes what has changed. Use imperative mood. Do not lead with a plural. e.g. Upgrade vs upgrades. Enable vs enables. Add vs adds. The second section is under the heading "### Why" and describes why the change is being made. Be concise with why, and avoid generic statements. If the change should close an issue, add "Close #ISSUENUMBER" to the end.

Start the title with a capital letter but do not end with a full stop. Use full sentences for what and why. Avoid generic phrases.

After the pull request has been opened, monitor the GitHub Actions runs and fix any failures before finishing.
