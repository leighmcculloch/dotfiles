# App Scheduler

A native macOS menu bar app that opens and quits apps on cron schedules.
Click its calendar icon and choose **Settings…** to configure it. Closing the
settings window leaves the scheduler running, with no Dock icon.

## Use

1. Click **Add Schedule**.
2. Choose **App** to select an app from the dropdown, or **URL** to enter an
   app URL such as `slack://` or a deep link including its query parameters.
3. Choose **Open** or **Quit** for an app. URLs support **Open** only and are
   handed to macOS to open with the app registered for their scheme. Enter a
   cron expression. New rows default to `0 9 * * 1-5` (9am Monday–Friday).
   The five text columns line up under **Minute**, **Hour**, **Day**, **Month**,
   and **Weekday** headings. **Day** means day of month. You can paste a complete
   five-field cron into any column to fill them all. A plain-language description
   beside the columns updates as you type, such as “At 9am on Monday–Friday” or
   “Every 15 minutes”.
4. Add as many rows as needed, including multiple rows for the same app or URL.
   For example, open Slack with `0 9 * * 1-5` and quit it with `0 17 * * 1-5`.

Changes save automatically. The checkbox enables or disables a row, and the
trash button removes it. Blank or invalid cron expressions show an inline
error and do not run. Existing time/day schedules migrate to equivalent cron
expressions automatically; rows with no selected days stay inactive.
The dropdown includes apps in `/Applications`, `/System/Applications`, and
`~/Applications`, including Utilities folders. **Add Other App…** lets you
select an app elsewhere. Saved app selections survive relaunches.

### Cron expressions

Use five numeric fields: **minute hour day-of-month month day-of-week**.

| Field | Values |
| --- | --- |
| Minute | 0–59 |
| Hour | 0–23 |
| Day of month | 1–31 |
| Month | 1–12 |
| Day of week | 0–7; Sunday = 0 or 7, Monday = 1 |

Each field supports `*` (all values), lists (`1,3,5`), inclusive ranges
(`1-5`), and steps (`*/15`, `7-47/20`). Steps restart within each field;
`*/15` in the minute field means minutes 0, 15, 30, and 45 each hour.
When both day-of-month and day-of-week are restricted, either can match,
as in standard cron; month must always match. If either day field starts
with `*`, both day fields must match. Seconds, year fields, names such as
`MON`, macros such as `@hourly`, and shell commands are not supported.

| Expression | Schedule |
| --- | --- |
| `0 9 * * 1-5` | 9am Monday–Friday |
| `*/15 * * * *` | Every 15 minutes |
| `0 */2 * * *` | Every two hours, on the hour |
| `30 8,17 * * *` | 8:30am and 5:30pm every day |
| `0 9 1 * *` | 9am on the first of each month |

URLs must include a scheme (for example, `myapp://open?document=123`). Leading
and trailing whitespace is ignored; encode spaces inside a URL as `%20`.
Blank or invalid URLs do not run. HTTP and HTTPS links are also supported and
open in the registered handler, normally your browser. Opening a URL can bring
its app to the foreground or perform the action specified by the deep link.
URL schedules save automatically alongside app schedules, and existing saved
app schedules remain compatible.

The menu bar dropdown starts with a compact summary of every schedule: action,
app or URL, and plain-language timing. Disabled and incomplete rows are labeled.
Long targets and descriptions are shortened in the summary; hover over a row
to see the full target, description, and cron expression.
The menu also has **Launch at Login** and **Quit App Scheduler**.

## Timing and safety

- Times follow the Mac’s current local time zone, not a fixed UTC offset.
- While awake, actions run within roughly 15 seconds of their scheduled minute.
- Five-field cron has one-minute resolution. A runtime cooldown also allows
  at most one action per app or exact URL in any 60 seconds, across all rows.
  This uses actual dispatch time, so late polls, waking, edits, and time zone
  changes cannot cause a rapid burst. Occurrences inside the cooldown are
  skipped, not queued; a busy `* * * * *` schedule may skip a minute if a poll
  is late. The cooldown lasts while App Scheduler remains running.
- If the Mac sleeps while the scheduler is running, it applies only the latest
  missed action for each app or exact URL on wake, rather than replaying every
  action. Different URLs stay independent, even if their schemes are the same.
  Catch-up searches at most the previous 366 days to bound scheduling work.
- If multiple rows target the same app or URL at the same time, the last row wins.
- Starting the scheduler does not replay actions missed while it was closed.
  Edits and time zone changes apply going forward.
- During daylight saving transitions, a skipped time runs at the next valid
  time that day; a repeated time runs once, at its first occurrence.
- **Open** launches the app without stealing focus. **Quit** requests a normal
  quit; it never force-kills an app. Apps may ask to save documents or refuse to
  quit. An already-closed app needs no action. The settings footer shows the
  latest result or error.

The scheduler must remain running. It cannot wake a sleeping Mac, perform
actions while logged out, or run after it has itself been quit. It does not
install background daemons or use AppleScript/Automation permissions.

## Build and install

Requires macOS 13 or later and Swift 5.9 or later. From this directory:

When updating an installed copy, first choose **Quit App Scheduler** from its
menu. Closing Settings or replacing the app bundle does not restart the running
app, so it will continue showing the old interface until it is relaunched.

```sh
make install
open "/Applications/App Scheduler.app"
```

Run the scheduling tests with `make test`.
