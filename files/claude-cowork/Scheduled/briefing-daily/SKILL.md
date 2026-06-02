---
name: briefing-daily
description: A briefing for the day.
---

Draft my standup update for sharing in Slack, covering the last `$ARGUMENTS` day(s) of activity. The goal is a concise, skimmable summary that gives the team a clear picture of what happened — code shipped, coordination done, and anything still in flight.
 
The user is GitHub user `leighmcculloch` (verify via `mcp__github__get_me`). The window is `$ARGUMENTS` days; e.g. `1` is a daily briefing, `7` is a weekly briefing. If `$ARGUMENTS` is empty or not a positive integer, default to `1`.
 
## Data sources
 
Gather information from all of these before writing anything. Run searches in parallel to save time.
 
### Slack channels (last `$ARGUMENTS` day(s), from me)
 
- All Slack channels I have commented in.
### GitHub activity (last `$ARGUMENTS` day(s))
 
- PRs opened by me
- PRs merged by me
- PRs reviewed by me (approvals, comments)
- Issues opened or closed by me
- Threads / discussions I participated in
### Google Calendar (last `$ARGUMENTS` day(s))
 
- My calendar only, any meetings I attended.
## Format rules
 
The update is written to a Slack Canvas using standard markdown. Each project gets a `###` header and a bullet list underneath.
 
### Structure
 
```
### [project-name] One-line summary of the project-level theme
- :emoji: Detail about a specific PR or action ([link text](url))
- :emoji: Another detail ([link text](url))
- :emoji: Coordination or non-code work ([thread](slack-url))
### [another-project] One-line summary
- :emoji: ...
### Other
- :eyes: Reviewed teammate PRs
- :pray: Thanks to anyone who helped unblock me (optional, only when genuine)
```
 
### Formatting notes
 
- Use `###` headers for project groups — no blank lines between sections (keep them tight).
- Use `-` bullet lists for items under each project.
- Use standard markdown links: `[text](url)` — **not** Slack mrkdwn `<url|text>`.
- Emojis use Slack's `:emoji:` syntax (they render fine in canvases).
### Emoji usage
 
Each bullet gets an emoji prefix that signals the type of work:
 
| Emoji | Meaning |
|-------|---------|
| `:github:` | A PR or code-related action (always include the PR link) |
| `:k8s:` | Infrastructure / deployment work (can combine with `:github:`) |
| `:speech_balloon:` | Coordination, discussion, or decision-making (link to Slack thread if possible) |
| `:hourglass_flowing_sand:` | Work in progress / ongoing item |
| `:arrow_forward:` | Presentation or demo |
| `:sweating:` | Something that was harder than expected or required extra iterations |
| `:eyes:` | Code reviews done for others |
| `:pray:` | Thanks / shoutouts |
 
### PR link format
 
Use standard markdown links with a short descriptor:
 
- `[repo#123](https://github.com/stellar/repo/pull/123)` when the repo belongs to the `stellar` org.
- `[org/repo#123](https://github.com/org/repo/pull/123)` when the repo belongs to another org.
When there are multiple PRs for the same sub-task, list them inline separated by commas.
 
### Grouping logic
 
- Group by **project**. Stellar-org repos don't need a prefix; external repos do (e.g. `[x402-stellar]`, `[coinbase/x402]`, `[pipelines]`, `[dashboard]`).
- If a project has only one bullet, it still gets its own top-level entry.
- Put the main / biggest project first.
- Reviews and shoutouts go at the bottom, under an `### Other` header.
### Tone
 
- Concise and factual — this isn't a narrative, it's a scannable list.
- A touch of personality is fine (`:sweating:` for hard stuff, brief color commentary), but keep it short.
- Don't over-explain what a PR does — the PR title + link is usually enough. Add context only when it's not obvious from the title (e.g. a performance finding, a workaround, a coordination story).
- Don't add greetings, sign-offs, or filler text. Jump straight into the project headers.
## Output destination
 
The update is written to a persistent Slack Canvas:
- For a 1 day period briefing: https://stellarfoundation.slack.com/docs/T02B046LB/F0AV41TNT5Z
- For any other number of days briefing: https://stellarfoundation.slack.com/docs/T02B046LB/F0AV96HUA3U
**Prepend** the new update to the canvas (so the latest entry is always at the top). Use a `##` header as a separator:
 
- For a 1-day window: `## March 23, 2026`
- For a multi-day window: `## March 17 – March 23, 2026` (the date range covered)
DO NOT create a new canvas each time — update the existing one via `slack_update_canvas`.
 
After writing, DM me the canvas link via `slack_send_message` so I can review.
 
## Process
 
1. Search all data sources in parallel for the `$ARGUMENTS`-day window.
2. Deduplicate — the same PR often shows up in both Slack and GitHub. Use the richer context but don't list it twice.
3. Group items by project.
4. Within each project, order roughly by importance / narrative flow, not chronologically.
5. Write the update to the canvas (prepend with the appropriate date header), then DM me the link for review.
