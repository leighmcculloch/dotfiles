# Stopwatch

A small, native macOS menu bar stopwatch. It shows a stopwatch icon and elapsed
time with monospaced digits, with no Dock icon or window.

- Initially shows `0:00` and is stopped.
- Click to start counting.
- Click again to stop and reset immediately to `0:00`.
- Click again to start a new stopwatch from zero. There is no pause/resume state.
- Right-click (or Control-click) for **Launch at Login** and **Quit**, without
  starting or resetting the stopwatch.

Time is displayed as `m:ss`, or `h:mm:ss` after an hour. The stopwatch uses a
continuous clock rather than counting timer callbacks, so elapsed time includes
time asleep and is unaffected by changes to the system clock. Quitting and
relaunching the app resets it to zero.

## Build and install

Requires macOS 13 or later and Swift 5.9 or later. From this directory:

```sh
make install
open "/Applications/Stopwatch.app"
```

Run the timing and formatting tests with `make test`.
