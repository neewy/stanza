#!/bin/bash

# Configuration
APP_NAME="Stanza"
BUNDLE_ID="com.neewy.stanza"
VERSION="1.0.0"
BUILD_DIR=".build/apple/Products/Release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ENTITLEMENTS="App.entitlements"

echo "Building $APP_NAME ($VERSION) for Release..."

# Build the executable
swift build -c release --arch arm64 --arch x86_64

# Create the bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy the binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Copy the icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES/"
fi

# Create Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCalendarsUsageDescription</key>
    <string>Stanza needs access to your calendar to display upcoming events and help you track time against them.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Stanza needs full access to your calendar to read and group your scheduled events for better time tracking insights.</string>
</dict>
</plist>
EOF

# Code signing (Ad-hoc with Entitlements)
echo "Signing $APP_NAME (Ad-hoc with Entitlements)..."
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "Success! Created $APP_BUNDLE"
