#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/MorseRadio.app"
APP_VERSION="${APP_VERSION:-1.1.0}"

cd "$ROOT"
swift build -c release

mkdir -p "$APP/Contents/MacOS"
cp ".build/release/MorseRadio" "$APP/Contents/MacOS/MorseRadio"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>MorseRadio</string>
    <key>CFBundleIdentifier</key><string>com.codex.MorseRadio</string>
    <key>CFBundleName</key><string>Morse Radio</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>同じ仮想周波数を選んだ近くの Morse Radio 利用者を検索して接続します。</string>
    <key>NSBonjourServices</key>
    <array><string>_morse-radio._tcp</string></array>
</dict>
</plist>
PLIST
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
