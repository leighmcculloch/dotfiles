# QR Reader

QR Reader is a small macOS menu bar app that finds every QR code in an image.
It uses Apple's Vision framework locally on the Mac; images are not uploaded
anywhere.

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

- In Finder or Preview, select or open an image, then choose **Services → Read
  QR Codes from Image**. The result window lists every QR payload it finds.
- Click the QR Reader icon in the menu bar and choose **Open Image…**, or drag
  an image onto the window.
- **Read Clipboard Image** scans an image copied to the clipboard.

Each result can be copied. Values that contain a URL can also be opened with
the default macOS app for that URL. Non-URL payloads, such as Wi-Fi setup
codes, are shown and can still be copied.

If the Service is not visible immediately after installation, enable **Read QR
Codes from Image** in **System Settings → Keyboard → Keyboard Shortcuts →
Services**.
