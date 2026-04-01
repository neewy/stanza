#!/bin/bash

# Configuration
APP_NAME="Stanza"
DMG_NAME="$APP_NAME.dmg"
APP_BUNDLE="$APP_NAME.app"
TEMP_DMG_DIR="temp_dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run scripts/build_app.sh first."
    exit 1
fi

echo "Creating DMG for $APP_NAME..."

# Check for create-dmg
if command -v create-dmg >/dev/null 2>&1; then
    echo "Using create-dmg to generate a premium disk image..."
    rm -f "$DMG_NAME"
    create-dmg \
      --volname "$APP_NAME Installer" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "$APP_BUNDLE" 175 190 \
      --hide-extension "$APP_BUNDLE" \
      --app-drop-link 425 190 \
      --volicon "Resources/AppIcon.icns" \
      "$DMG_NAME" \
      "$APP_BUNDLE" \
      "DEVELOPMENT_NOTICE.txt"
else
    echo "create-dmg not found. Falling back to built-in hdiutil..."
    echo "Note: install 'create-dmg' via Homebrew for a better looking DMG."
    
    # Simple hdiutil approach
    mkdir -p "$TEMP_DMG_DIR"
    cp -R "$APP_BUNDLE" "$TEMP_DMG_DIR/"
    cp "DEVELOPMENT_NOTICE.txt" "$TEMP_DMG_DIR/"
    ln -s /Applications "$TEMP_DMG_DIR/Applications"
    
    rm -f "$DMG_NAME"
    hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_NAME"
    
    rm -rf "$TEMP_DMG_DIR"
fi

echo "Success! Created $DMG_NAME"
