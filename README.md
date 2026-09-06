# SakuraPhoto

A native macOS photo organizer built with Swift and SwiftUI. SakuraPhoto reads
capture dates from image metadata, previews the changes, then sorts photos into
date folders using names such as `2026-09-06_17-42-03.0.jpg`.

The scan and organization happen entirely on the Mac. JPEG, PNG, and Sony ARW
files are supported, including the Sony A7R V's ARW and HEIF/HIF captures.
Matching XMP and XML sidecars move with each photo.

## Project structure

The Swift package is organized by responsibility:

- `App/` contains the application scene and shared view model.
- `Domain/` contains source, classification, pattern, and plan types.
- `Infrastructure/` contains the `PhotoDataStore` implementation that reads
  ImageIO metadata and performs safe file operations.
- `Features/Organizer/` contains the SwiftUI browsing and organization feature.

`PhotoDataStore` is the extension point for future stores. The current local
implementation handles regular folders and Sony A7R V camera media through the
same source protocol.

Sources are identified by volume UUID plus their path relative to that volume,
so removable media continues to be recognized when macOS assigns it a new mount
name. Source bookmarks and the last known location are saved under
`~/Library/Application Support/SakuraPhoto/workspace.json`; unavailable cards
are shown as offline until remounted.

Sony cards can be selected at their mounted volume root. SakuraPhoto recognizes
the camera's `DCIM`, `MP_ROOT`, and `PRIVATE/M4ROOT/CLIP` directories and scans
the media folders without treating unrelated card files as photos.

## Run

Requires macOS 14 or newer and Xcode 16 or a compatible Swift toolchain.

```sh
swift run SakuraPhoto
```

You can also open the repository directory in Xcode as a Swift package and run
the `SakuraPhoto` executable.

## Use

1. Choose the folder containing the photos.
2. Add one or more regular folders, or select a mounted Sony A7R V card. The
   source detector recognizes Sony media by its volume/DCIM layout.
3. Review thumbnails, classify photos as Keep, Review, or Reject, and adjust
   the rename pattern. Supported tokens are `{date}`, `{time}`, `{year}`,
   `{month}`, `{day}`, `{seq}`, `{original}`, `{class}`, and `{ext}`.
4. Click **Organize Photos**, then confirm the operation. Files without an EXIF
   capture date remain in place and are clearly marked.

SakuraPhoto creates `YYYY-MM-DD` folders below the selected folder and renames
photos to `YYYY-MM-DD_HH-MM-SS.N.ext`. Existing files are never overwritten.
