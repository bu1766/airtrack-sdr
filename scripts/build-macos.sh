#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.1.0}"
ARCH="$(uname -m)"
BREW_PREFIX="$(brew --prefix)"
DIST="$ROOT/dist"
BUILD_ROOT="${TMPDIR:-/tmp}/airtrack-sdr-build-$ARCH"
APP="$BUILD_ROOT/AirTrack SDR.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

rm -rf "$DIST" "$BUILD_ROOT"
mkdir -p "$DIST"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

swiftc -O -target "${ARCH}-apple-macosx13.0" \
  -framework AppKit -framework WebKit -framework Network \
  "$ROOT/Sources/AirTrackSDR/main.swift" -o "$MACOS/AirTrackSDR"

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
cp -R "$ROOT/Resources/Web" "$RESOURCES/Web"
cp "$ROOT/LICENSE" "$RESOURCES/LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$RESOURCES/THIRD_PARTY_NOTICES.md"

ICON_WORK="$BUILD_ROOT/AirTrackSDR.iconset"
mkdir -p "$ICON_WORK"
swift "$ROOT/scripts/generate-icon.swift" "$BUILD_ROOT/icon-1024.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BUILD_ROOT/icon-1024.png" --out "$ICON_WORK/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$BUILD_ROOT/icon-1024.png" --out "$ICON_WORK/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICON_WORK" -o "$RESOURCES/AirTrackSDR.icns"

cp "$BREW_PREFIX/bin/dump1090" "$MACOS/dump1090"
cp "$BREW_PREFIX/bin/rtl_test" "$MACOS/rtl_test"
cp "$BREW_PREFIX/bin/bladeRF-cli" "$MACOS/bladeRF-cli"

cp "$(brew --prefix librtlsdr)/lib/librtlsdr.0.dylib" "$FRAMEWORKS/"
cp "$(brew --prefix libbladerf)/lib/libbladeRF.2.dylib" "$FRAMEWORKS/"
cp "$(brew --prefix libusb)/lib/libusb-1.0.0.dylib" "$FRAMEWORKS/"
cp "$(brew --prefix ncurses)/lib/libncursesw.6.dylib" "$FRAMEWORKS/"

install_name_tool -id @rpath/librtlsdr.0.dylib "$FRAMEWORKS/librtlsdr.0.dylib"
install_name_tool -id @rpath/libbladeRF.2.dylib "$FRAMEWORKS/libbladeRF.2.dylib"
install_name_tool -id @rpath/libusb-1.0.0.dylib "$FRAMEWORKS/libusb-1.0.0.dylib"
install_name_tool -id @rpath/libncursesw.6.dylib "$FRAMEWORKS/libncursesw.6.dylib"

for file in "$MACOS/dump1090" "$MACOS/rtl_test" "$MACOS/bladeRF-cli"; do
  install_name_tool -add_rpath @executable_path/../Frameworks "$file" 2>/dev/null || true
done

rewrite_dependency() {
  local file="$1" old="$2" new="$3"
  if otool -L "$file" | grep -Fq "$old"; then install_name_tool -change "$old" "$new" "$file"; fi
}

for file in "$MACOS/dump1090" "$MACOS/rtl_test"; do
  rewrite_dependency "$file" "$BREW_PREFIX/opt/librtlsdr/lib/librtlsdr.0.dylib" @rpath/librtlsdr.0.dylib
done
for file in "$MACOS/dump1090" "$MACOS/bladeRF-cli"; do
  rewrite_dependency "$file" "$BREW_PREFIX/opt/libbladerf/lib/libbladeRF.2.dylib" @rpath/libbladeRF.2.dylib
done
rewrite_dependency "$MACOS/dump1090" "$BREW_PREFIX/opt/ncurses/lib/libncursesw.6.dylib" @rpath/libncursesw.6.dylib
for file in "$MACOS/rtl_test" "$MACOS/bladeRF-cli" "$FRAMEWORKS/librtlsdr.0.dylib" "$FRAMEWORKS/libbladeRF.2.dylib"; do
  rewrite_dependency "$file" "$BREW_PREFIX/opt/libusb/lib/libusb-1.0.0.dylib" @rpath/libusb-1.0.0.dylib
done

chmod +x "$MACOS"/*
chmod -R u+w "$APP"
xattr -cr "$APP"
for file in "$FRAMEWORKS"/*.dylib "$MACOS/dump1090" "$MACOS/rtl_test" "$MACOS/bladeRF-cli" "$MACOS/AirTrackSDR"; do
  codesign --force --sign - --timestamp=none "$file"
done
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$BUILD_ROOT/dmg"
cp -R "$APP" "$BUILD_ROOT/dmg/"
ln -s /Applications "$BUILD_ROOT/dmg/Applications"
hdiutil create -quiet -volname "AirTrack SDR" -srcfolder "$BUILD_ROOT/dmg" -ov -format UDZO "$DIST/AirTrack-SDR-$VERSION-$ARCH.dmg"
rm -rf "$BUILD_ROOT/dmg"
printf '%s\n' "$APP" > "$DIST/.app-path"
(cd "$DIST" && shasum -a 256 "AirTrack-SDR-$VERSION-$ARCH.dmg" > "SHA256SUMS-$ARCH.txt")
echo "$DIST/AirTrack-SDR-$VERSION-$ARCH.dmg"
