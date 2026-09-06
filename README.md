# SakuraPhoto

A native macOS photo organizer built with Swift and SwiftUI. SakuraPhoto reads
capture dates from image metadata, previews the changes, then sorts photos into
date folders using names such as `2026-09-06_17-42-03.0.jpg`.

The scan and organization happen entirely on the Mac. JPEG, PNG, and Sony ARW
files are supported. Matching XMP and XML sidecars move with each photo.

## Run

Requires macOS 14 or newer and Xcode 16 or a compatible Swift toolchain.

```sh
swift run SakuraPhoto
```

You can also open the repository directory in Xcode as a Swift package and run
the `SakuraPhoto` executable.

## Use

1. Choose the folder containing the photos.
2. Review the proposed destination of every image. Files without an EXIF
   capture date remain in place and are clearly marked.
3. Click **Organize Photos**, then confirm the operation.

SakuraPhoto creates `YYYY-MM-DD` folders below the selected folder and renames
photos to `YYYY-MM-DD_HH-MM-SS.N.ext`. Existing files are never overwritten.
