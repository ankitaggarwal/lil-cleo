#!/bin/bash
# Package LilCleo into a runnable LilCleo.app and a drag-install LilCleo.dmg.
#
#   tools/package.sh            # build app + dmg into dist/
#   tools/package.sh app        # just the .app
#   make app  /  make dmg
#
# The app is ad-hoc code-signed so it runs locally. It is NOT notarized (that needs
# a paid Apple Developer ID), so on another Mac the first launch is right-click ▸
# Open (or: xattr -dr com.apple.quarantine /Applications/LilCleo.app).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="LilCleo"
VERSION="${LILCLEO_VERSION:-1.0.0}"
BUNDLE_ID="com.curious.lilcleo"
DIST="dist"
APP="$DIST/$APP_NAME.app"
BIN=".build/release/$APP_NAME"
RES_BUNDLE=".build/release/${APP_NAME}_${APP_NAME}.bundle"
HERO="Sources/LilCleo/Resources/characters/brick/hero.png"
WHAT="${1:-all}"

echo "▸ Release build"
swift build -c release

echo "▸ Assembling $APP"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"

echo "▸ App icon (from $HERO)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
# Compose a clean square 1024 master: soft rounded background + Brick centered.
python3 - "$HERO" "$ICONSET/master.png" <<'PY'
import sys
from PIL import Image, ImageDraw
hero_path, out = sys.argv[1], sys.argv[2]
S = 1024
bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(bg)
# rounded-rect gradient-ish background (teal → sky)
top, bot = (110, 196, 184), (138, 180, 232)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=(int(top[0]+(bot[0]-top[0])*t),
                                   int(top[1]+(bot[1]-top[1])*t),
                                   int(top[2]+(bot[2]-top[2])*t), 255))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], radius=int(S*0.225), fill=255)
bg.putalpha(mask)
hero = Image.open(hero_path).convert("RGBA")
scale = (S * 0.62) / max(hero.size)
hero = hero.resize((int(hero.width*scale), int(hero.height*scale)))
bg.alpha_composite(hero, ((S-hero.width)//2, int(S*0.16)))
bg.save(out)
PY
for s in 16 32 64 128 256 512 1024; do
    sips -z $s $s "$ICONSET/master.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done
# @2x variants iconutil expects
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png" "$ICONSET/master.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

echo "▸ Ad-hoc code sign"
codesign --force --deep --sign - "$APP"
echo "✓ Built $APP"

if [ "$WHAT" = "app" ]; then exit 0; fi

echo "▸ Building DMG"
STAGE="$DIST/dmg"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$APP_NAME.dmg" >/dev/null
rm -rf "$STAGE"
echo "✓ Built $DIST/$APP_NAME.dmg"
