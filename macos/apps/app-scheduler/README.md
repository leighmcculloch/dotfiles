# App Scheduler

A native macOS menu bar app that opens and quits apps on a weekly schedule.
Click its calendar icon and choose **Settings…** to configure it. Closing the
settings window leaves the scheduler running, with no Dock icon.

## Use

1. Click **Add Schedule**.
2. Choose **App** to select an app from the dropdown, or **URL** to enter an
   app URL such as `slack://` or a deep link including its query parameters.
3. Choose **Open** or **Quit** for an app. URLs support **Open** only and are
   handed to macOS to open with the app registered for their scheme. Set the
   time and days of the week. New rows default to Monday–Friday.
4. Add as many rows as needed, including multiple rows for the same app or URL.
   For example, open Slack at 9:00 AM and quit it at 5:00 PM on weekdays.

Changes save automatically. The checkbox enables or disables a row, and the
trash button removes it. No selected days means the row will not run.
The dropdown includes apps in `/Applications`, `/System/Applications`, and
`~/Applications`, including Utilities folders. **Add Other App…** lets you
select an app elsewhere. Saved app selections survive relaunches.

URLs must include a scheme (for example, `myapp://open?document=123`). Leading
and trailing whitespace is ignored; encode spaces inside a URL as `%20`.
Blank or invalid URLs do not run. HTTP and HTTPS links are also supported and
open in the registered handler, normally your browser. Opening a URL can bring
its app to the foreground or perform the action specified by the deep link.
URL schedules save automatically alongside app schedules, and existing saved
app schedules remain compatible.

The menu also has **Launch at Login** and **Quit App Scheduler**.

## Timing and safety

- Times follow the Mac’s current local time zone, not a fixed UTC offset.
- While awake, actions run within roughly 15 seconds of their scheduled minute.
- If the Mac sleeps while the scheduler is running, it applies only the latest
  missed action for each app or exact URL on wake, rather than replaying every
  action. Different URLs stay independent, even if their schemes are the same.
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

```sh
make install
open "/Applications/App Scheduler.app"
```

Run the scheduling tests with `make test`.
