#!/bin/bash

echo "🏗️  Building Volcano Game..."

# Build using Swift Package Manager
swift build --configuration release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"

    # Create app bundle structure
    APP_NAME="VolcanoGame"
    APP_PATH="/Applications/$APP_NAME.app"
    EXECUTABLE="./.build/release/$APP_NAME"

    echo "📦 Creating app bundle..."

    # Check if we can write to /Applications
    if [ ! -w "/Applications" ]; then
        echo "⚠️  Need sudo permissions to install to /Applications"
        echo "Run: sudo ./build.sh"
        exit 1
    fi

    # Remove old app if exists
    rm -rf "$APP_PATH"

    # Create app bundle structure
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"

    # Copy executable
    cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/"

    # Copy Info.plist
    cp "Info.plist" "$APP_PATH/Contents/"

    # Create basic PkgInfo
    echo "APPL????" > "$APP_PATH/Contents/PkgInfo"

    echo "🎮 Installing to /Applications/$APP_NAME.app"
    echo "🚀 Launching app..."

    # Launch the app
    open "$APP_PATH"

else
    echo "❌ Build failed!"
    exit 1
fi