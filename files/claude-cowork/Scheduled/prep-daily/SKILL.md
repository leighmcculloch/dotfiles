---
name: prep-daily
description: Meeting prep for the next day's calendar, posted to a Slack Canvas.
---

Prepare a meeting-prep briefing for my meetings **tomorrow** (the next calendar day after this task runs) and prepend it to a Slack Canvas. Each run starts fresh with no memory of prior runs, so follow these steps end to end. I am leigh@stellar.org.

## Target day

- Determine tomorrow's date in my local timezone (the day after the run date). This task only runs Monday–Thursday, so the target day is always Tuesday–Friday.
- Show all meeting times in my local timezone.

## Step 1 — Pull tomorrow's meetings (Google Calendar)

- Use the Google Calendar connector to list events on my calendar (leigh@stellar.org) for the target day.
- Include only events where I'm an attendee or organizer. Skip all-day events, events I've declined, and personal focus/hold blocks that have no other attendees (use judgment).
- Order the events chronologically by start time.
- For each event capture: title, start–end time, and the FULL attendee list exactly as listed in Google Calendar. Record each attendee's name and email/handle (the email helps match them in Slack).

## Step 2 — Read attached agendas & notes

- For each meeting, find any agenda or notes documents attached to or linked from the calendar event. Check BOTH the event's file attachments AND any Google Docs/Drive links in the event description or location field.
- Open and read those documents using the Google Drive connector.
- From them extract: (a) the agenda / topics planned for this meeting, and (b) ALL open or carried-over action items from previous meetings — every action item recorded, not just mine — along with who each one is assigned to.

## Step 3 — Surface Slack context on attendees

- For each meeting, search Slack (public + private channels I'm in) for recent conversations from the LAST 2 WEEKS involving the attendees and/or the meeting topic.
- Goal: surface useful context on what the attendees are currently aware of, working on, or care about that's relevant to this meeting — recent decisions, blockers, hot topics, concerns they've raised.
- Keep each point concise and link out to the source Slack conversation so I can click through for more — do NOT cram lots of detail into the summary. The bullet should be a short pointer plus a link, not a full recap.
- Only include genuinely relevant items. Skip a meeting's context section entirely if nothing useful turns up.
- Run searches across meetings in parallel where possible to save time.

## Output format

Write to the canvas using standard markdown. Prepend a new dated section at the very TOP of the canvas (latest entry always on top). Use a `##` header for the day, formatted with the weekday and full date, e.g. `## Thursday, June 4, 2026`.

Under the date header, one `###` block per meeting in chronological order, structured like this:

```
### 9:00–9:30 AM — [Meeting title]
**Attendees:** Name, Name, Name

**Agenda:** ([agenda doc](url))
- Planned topic / discussion point
- Another topic

**Prior action items:**
- Action item text — Owner: Name
- Another action item — Owner: Name

**Context:**
- Short pointer to what an attendee is tracking or cares about ([#channel](slack-url))
- Another concise point ([thread](slack-url))
```

Formatting and link rules (important — links must render as clickable in Slack):
- In the canvas, ALWAYS write links as standard markdown `[label](url)`. This is what renders as a clickable link in a Slack Canvas. Do NOT use Slack mrkdwn `<url|label>` in the canvas — it does not render there.
- Keep link labels short and descriptive (the doc name, `#channel`, `thread`, or a person's name) so the canvas is easy to scan and navigate.
- Meetings in chronological order; one `###` block per meeting.
- Agenda and Prior action items are bullet lists. If no agenda doc is attached, write "No agenda doc attached." in place of the agenda bullets (and omit the doc link). If there are no prior action items, write "None found."
- Each prior action item must name its owner (Owner: Name). Include items assigned to anyone, not just me.
- Context is a concise bullet list, each bullet ending with a link to the source conversation. Omit the whole **Context:** section for a meeting if nothing useful was found.
- Keep it skimmable and factual. No greetings, no sign-offs, no filler.
- If there are no meetings tomorrow, write a single line under the date header: "No meetings scheduled."

## Destination

- The persistent Slack Canvas: https://stellarfoundation.slack.com/docs/T02B046LB/F0AV70V60GM
- **Prepend** the new dated section to the top of the existing canvas using `slack_update_canvas`. Do NOT create a new canvas each run — update this existing one.
- After updating, DM me the canvas link via `slack_send_message`, posting the full canvas URL on its own line so Slack auto-links it and I can click straight through.

## Process

1. List tomorrow's meetings (Step 1).
2. For each meeting, in parallel where possible: read its attached agenda/notes docs (Step 2) and search Slack for attendee context over the last 2 weeks (Step 3).
3. Assemble the dated section in chronological order.
4. Prepend it to the canvas, then DM me the canvas link.