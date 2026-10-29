#!/bin/bash
# Builds Pangolin.app into ./build. --install copies it to /Applications; --dmg also makes build/Pangolin.dmg.
set -euo pipefail
cd "$(dirname "$0")"

# The macOS 27 SDK needs SwiftUI macro plugins that ship only with full Xcode; the 26 SDK works with the CLT.
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
fi
swift build -c release
BIN=.build/release/Pangolin
APP=build/Pangolin.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pangolin"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon, rendered from the same SwiftUI mascot the app uses.
ICONSET=build/Pangolin.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
"$BIN" --render-icon build/icon_1024.png
for size in 16 32 128 256 512; do
  sips -z $size $size build/icon_1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) build/icon_1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Pangolin.icns"

codesign --force --deep --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  # Drag-to-Applications disk image for customers.
  STAGE=build/dmg
  rm -rf "$STAGE" && mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  rm -f build/Pangolin.dmg
  hdiutil create -volname Pangolin -srcfolder "$STAGE" -ov -format UDZO build/Pangolin.dmg >/dev/null
  echo "Built build/Pangolin.dmg"
fi

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Pangolin 2>/dev/null || true
  rm -rf /Applications/Pangolin.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Pangolin.app"
fi
