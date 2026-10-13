# Colour Blindness

A small **Dock app**, not a menu bar app, that simulates colour vision across
all connected displays. Live, click-through overlays let you continue using
your other apps while their colours are transformed. The app's own window,
the desktop, Dock and menu bar are transformed too.

## Requirements

- macOS 13 or later, with a Metal-capable GPU
- Swift 5.9 or later to build
- Screen Recording permission (no Accessibility permission is needed)

## Install

```sh
make -C macos/apps/colour-blindness install
open "/Applications/Colour Blindness.app"
```

From this directory, `make run` builds and opens the local bundle, and
`make test` runs the simulation model tests. Like the other apps in this
repository, the bundle is ad-hoc signed and needs no Xcode project or
third-party dependencies.

## Use

1. Open **Colour Blindness** from Applications or the Dock.
2. Choose a vision type, then click **Start Simulation**.
3. On first use, allow the app in **System Settings → Privacy & Security →
   Screen Recording** (called **Screen & System Audio Recording** on newer
   macOS versions). Quit and reopen the app if macOS requests it. The app has
   a button that opens this settings page.
4. Switch types while running. Partial deficiencies have an adjustable
   severity slider; 0% is normal vision and 100% is the full deficiency.
5. Click **Stop Simulation**, press **⌘.** with the app focused, or quit
   with **⌘Q** or the Dock's **Quit** command to restore the normal display.

Minimising the window or switching to another app keeps the simulation on.
Closing the controls window stops it; click the Dock icon to reopen the
controls. The simulation starts off on every launch. Sleep, session changes,
display reconnection/resolution changes and capture/render errors stop the
simulation; start it again when ready.

## Simulation types

| Type | Simulation |
| --- | --- |
| Protanopia | Red-blind |
| Deuteranopia | Green-blind |
| Tritanopia | Blue-blind |
| Protanomaly | Reduced red sensitivity |
| Deuteranomaly | Reduced green sensitivity |
| Tritanomaly | Reduced blue sensitivity |
| Achromatopsia | No colour vision (greyscale approximation) |
| Achromatomaly | Reduced colour vision (desaturation approximation) |

The red/green/blue simulations use the published
[Machado, Oliveira & Fernandes (2009) matrices](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html).
Intermediate severities interpolate the neighbouring 0.1-step matrices.
Transforms run in linear sRGB, with conversion back to display sRGB after
clipping out-of-gamut values. The achromatic modes use linear-light Rec. 709
luminance and are approximations, not clinical models. These eight modes
cover the usual colour-vision simulation categories, not every individual
eye condition; the app does not simulate reduced acuity or light sensitivity
and is not a medical test.

## How it works and limitations

ScreenCaptureKit captures each display at up to 30 fps. Core Image and Metal
transform the frames and show them in borderless, non-interactive windows
above the desktop, including other apps' full-screen Spaces. Only the overlay
windows are excluded from capture, preventing recursive feedback. Nothing
is saved, transmitted, or recorded to disk; audio is not captured. Display
profiles, gamma tables and macOS accessibility colour settings are untouched,
so quitting or a crash removes the effect without leaving altered settings.

This is a live screen overlay, **not a hardware display filter**:

- There is capture/render latency and ongoing GPU/memory use, especially on
  multiple Retina displays. Colours are simulated in SDR sRGB; wide-gamut
  and HDR content is not reproduced faithfully.
- The hardware mouse cursor remains unfiltered. Protected/DRM video and
  secure system surfaces that macOS does not share cannot be simulated.
- macOS may show a screen-sharing indicator or periodically ask to renew
  permission. Do not use this to bypass screen-capture restrictions.
- If capture becomes unavailable or stops producing frames, overlays are
  removed rather than leaving a frozen desktop over your apps.
- Other screen capture/sharing software may capture the simulated overlays;
  stop the simulation before sharing if you want the original colours.

Native verification requires a Mac: check permission denial/grant, all eight
modes, severity changes, clicking through to other apps, multiple displays
and full-screen Spaces, Dock reopening, closing/quitting, and sleep/display
changes. Model tests alone do not verify screen capture or native rendering.
