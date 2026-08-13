#!/bin/bash
# Bundle-only part of darkware-zapret's create_app.sh (no DMG, no Finder scripting).
set -e

cd "$HOME/develop/darkware-zapret"

APP_NAME="darkware zapret"
BUNDLE_IDENTIFIER="com.darkware.zapret"
VERSION="${1:-1.0.39-local}"
APP="$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/DarkwareZapret" "$APP/Contents/MacOS/$APP_NAME"
cp -R "zapret_src" "$APP/Contents/Resources/zapret"
cp "install_darkware.sh" "$APP/Contents/Resources/"
cp "DarkwareZapret.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/Resources/install_darkware.sh"
touch "$APP"

codesign --force --deep --sign - "$APP"
codesign -dv "$APP" 2>&1 | head -5
echo "OK: $PWD/$APP"
