# Video Compressor

A small native macOS app, like QR Reader, for dropping a video onto a window
and writing a compressed MP4 alongside it. Videos are processed locally using
FFmpeg; nothing is uploaded.

## Requirements and installation

- macOS 13 or later and Swift 5.9 or later.
- FFmpeg: `brew install ffmpeg` (already included in this repository's Brewfile).
  Finder-launched apps find Homebrew in both `/opt/homebrew/bin` and `/usr/local/bin`.

```sh
make install
open "/Applications/Video Compressor.app"
```

`make build` builds and ad-hoc signs the app; `make run` opens the build.
The repository's app installation commands also install Video Compressor.

## Use

Choose options **before** dropping a video into the window or clicking
**Open Video…** (⌘O). Finder's **Open With → Video Compressor** also works.
One video is processed at a time; MP4 and MOV are supported inputs.

The output is always MP4. For `holiday.mov`, the app creates
`holiday-compressed.mp4` in the same directory. If that name exists, it uses
`holiday-compressed-2.mp4`, then `-3`, and so on. Existing files are never
overwritten. Incomplete files are hidden while encoding and removed on failure
or cancellation. The source directory must be writable and have enough free
space for the output alongside the original.

The window shows activity, a **Cancel** button, the original and output sizes,
and **Show in Finder** when complete. Closing or quitting during compression
offers to stop and removes unfinished output before exiting.

## Options and defaults

The defaults come directly from
[FFmpeg: Reducing the size of videos](https://leighm.cc/posts/ffmpeg-reducing-size-of-videos/):

| Format | Balanced (default quality) | Higher quality | Smaller file |
| --- | --- | --- | --- |
| **H.265 / HEVC (default)** | CRF 28 | CRF 24 | CRF 32 |
| H.264 (wider compatibility) | CRF 20 | CRF 16 | CRF 24 |

All choices use AAC audio at 128 kb/s, retain the source resolution and frame
rate, and use FFmpeg's default software encoding speed. H.265 uses the `hvc1`
tag for Apple playback compatibility. The selected CRF is visible in the UI.

The balanced recipes are:

```sh
ffmpeg -i "$in" -c:v libx265 -crf 28 -tag:v hvc1 -c:a aac -b:a 128k "$out"
ffmpeg -i "$in" -c:v libx264 -crf 20 -c:a aac -b:a 128k "$out"
```

Compression is lossy and savings are not guaranteed, especially for already
compressed videos. If the output is larger, the app says so rather than claiming
space was saved. Software H.265 encoding can be slow. Review playback, quality,
HDR/color, and metadata before choosing to delete any original yourself; this
is not a lossless archival tool and does not promise to preserve every stream
or item of metadata.

## Tests

Run `make test`. The core tests can also run on Linux with Swift installed;
AppKit and app bundling still require macOS. FFmpeg integration tests generate
small synthetic videos and verify the encoded streams, playable output,
collision-safe names, original preservation, and cleanup. They skip if FFmpeg
or FFprobe is unavailable.
