#!/bin/bash
set -e

APP_NAME="Claude2xNotifier"
BUNDLE_ID="com.claude2x.notifier"
APP_DIR="/Applications/Claude2xNotifier.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="$BUNDLE_ID.plist"

echo "Installing $APP_NAME..."

pkill -f "Claude2xNotifier" 2>/dev/null || true
sleep 1

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<INFOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>Claude Peak Monitor</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
INFOPLIST

# Ad-hoc codesign the bundle (required on modern macOS)
codesign --force --sign - "$APP_DIR"

echo "  App Bundle -> $APP_DIR"

mkdir -p "$LAUNCH_AGENT_DIR"
cat > "$LAUNCH_AGENT_DIR/$PLIST_NAME" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>open</string>
        <string>-a</string>
        <string>$APP_DIR</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
AGENT
echo "  Launch Agent -> $LAUNCH_AGENT_DIR/$PLIST_NAME"

launchctl unload "$LAUNCH_AGENT_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT_DIR/$PLIST_NAME"

open -a "$APP_DIR"

echo ""
echo "Done! $APP_NAME is now running in your menu bar."
echo "It will auto-start on login."
