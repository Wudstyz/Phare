#!/bin/bash
# Construit Phare.app (Mac Apple Silicon, autonome : rien à installer).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Phare.app"
VERSION="1.0"

echo "→ Icône"
swift tools/make_icon.swift assets/icon.png
ICONSET="$(mktemp -d)/icon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) assets/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o assets/icon.icns

echo "→ Compilation (arm64, release)"
swift build -c release --arch arm64

echo "→ Assemblage de l'app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/Phare "$APP/Contents/MacOS/Phare"
cp assets/icon.icns "$APP/Contents/Resources/icon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Phare</string>
  <key>CFBundleDisplayName</key><string>Phare</string>
  <key>CFBundleIdentifier</key><string>com.woodstyles.phare</string>
  <key>CFBundleExecutable</key><string>Phare</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSRequiresAquaSystemAppearance</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict>
</plist>
EOF

echo "→ Signature ad hoc"
codesign --force --sign - "$APP/Contents/MacOS/Phare"
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP"
echo "OK : $APP"
