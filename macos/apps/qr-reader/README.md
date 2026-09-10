# QR Reader

QR Reader is a small macOS app that finds every QR code in an image. It shows
the image in a simple Preview-like window and highlights each detected code.
Click a highlight to copy its value or open it when it contains a link. It
uses Apple's Vision and Core Image frameworks locally on the Mac; images are
not uploaded anywhere.

## Requirements

- macOS 13 or later
- Swift 5.9 or later

## Install

From this directory:

```sh
make install
open "/Applications/QR Reader.app"
```

No Xcode project or third-party QR library is required.

## Use

- Launch **QR Reader**, then click **Open Image…** or drag an image into the
  window. You can also click **Paste Image** after copying an image.
- Each detected QR code is shown with a numbered highlight. Click a highlight
  to see its decoded value and the available **Copy Value** or **Open Link**
  action.
- As an optional shortcut, select an image in Finder or Preview and choose
  **Services → Read QR Codes from Image**. The image opens in QR Reader with
  its highlights.

Each result can be copied. Values that contain a URL can also be opened with
the default macOS app for that URL. Non-URL payloads, such as Wi-Fi setup
codes, are shown and can still be copied.

If the Service is not visible immediately after installation, enable **Read QR
Codes from Image** in **System Settings → Keyboard → Keyboard Shortcuts →
Services**, then quit and reopen Finder or Preview. If the Service is visible
but an older install is still running, quit **QR Reader** once before opening
the newly installed copy. The normal app window does not depend on the
Service being enabled.
