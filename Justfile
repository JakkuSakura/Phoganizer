# SakuraPhoto tasks, following SakuraDisk's SwiftPM workflow.

run:
    cd . && swift run SakuraPhoto

build:
    swift build

check:
    swift build

# Build an unsigned app for local use. Signing and notarization are left to
# the machine's normal Xcode/release workflow.
package:
    #!/usr/bin/env bash
    set -euo pipefail
    swift build -c release
    APP="dist/SakuraPhoto.app"
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cp .build/arm64-apple-macosx/release/SakuraPhoto "$APP/Contents/MacOS/SakuraPhoto"
    cp packaging/Info.plist "$APP/Contents/Info.plist"
    codesign --force --sign - "$APP"
    echo "Packaged $APP"
