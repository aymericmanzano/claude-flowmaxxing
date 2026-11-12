#!/bin/zsh
# Compile ClaudeFlowmaxxing, assemble l'app et fabrique le DMG dans build/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64

APP=build/ClaudeFlowmaxxing.app
rm -rf build/ClaudeFlowmaxxing.app build/dmg build/ClaudeFlowmaxxing.dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --arch arm64 --show-bin-path)/ClaudeFlowmaxxing" "$APP/Contents/MacOS/ClaudeFlowmaxxing"
cp Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/" && \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"

# Signature locale (pas de compte développeur) : premier lancement par clic droit, Ouvrir.
codesign --force --deep --sign - "$APP"

mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname ClaudeFlowmaxxing -srcfolder build/dmg -ov -format UDZO build/ClaudeFlowmaxxing.dmg >/dev/null
rm -rf build/dmg
echo "OK : build/ClaudeFlowmaxxing.dmg"
