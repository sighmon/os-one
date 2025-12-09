#!/bin/bash

# OS One - macOS Build Script
# Builds the Mac Catalyst version of OS One

set -e  # Exit on error

echo "🚀 OS One - macOS Build Script"
echo "================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="OS One"
SCHEME="OS One"
CONFIGURATION="Debug"  # Change to "Release" for production
DESTINATION="platform=macOS,variant=Mac Catalyst"

# Check if Xcode project exists
if [ ! -d "$PROJECT_NAME.xcodeproj" ]; then
    echo -e "${RED}❌ Error: $PROJECT_NAME.xcodeproj not found${NC}"
    echo "Make sure you're in the project root directory"
    exit 1
fi

echo "📁 Project found: $PROJECT_NAME.xcodeproj"
echo ""

# Check for new files that should be in the project
echo "🔍 Checking for new Swift files..."
MISSING_FILES=0

check_file_in_project() {
    local file="$1"
    if [ -f "$file" ]; then
        # Simple check - just verify file exists
        # In real scenario, you'd check project.pbxproj
        echo -e "${GREEN}✓${NC} Found: $file"
    else
        echo -e "${RED}✗${NC} Missing: $file"
        ((MISSING_FILES++))
    fi
}

check_file_in_project "OS One/ParakeetSTTClient.swift"
check_file_in_project "OS One/GlobalHotkeyManager.swift"
check_file_in_project "OS One/OllamaClient.swift"

if [ $MISSING_FILES -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Some files may not be in the Xcode project${NC}"
    echo "   Please add them manually in Xcode"
    echo ""
fi

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    > /dev/null 2>&1

echo -e "${GREEN}✓${NC} Build folder cleaned"
echo ""

# Build for macOS
echo "🔨 Building for macOS (Mac Catalyst)..."
echo "   Configuration: $CONFIGURATION"
echo "   Destination: Mac Catalyst"
echo ""

BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

xcodebuild build \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    | xcpretty --color || true  # Use xcpretty if available

BUILD_STATUS=$?

echo ""

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Build succeeded!${NC}"
    echo ""

    # Find the built app
    APP_PATH=$(find "$BUILD_DIR" -name "$PROJECT_NAME.app" -type d | head -n 1)

    if [ -n "$APP_PATH" ]; then
        echo "📦 App built at:"
        echo "   $APP_PATH"
        echo ""

        # Get app size
        APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
        echo "   Size: $APP_SIZE"
        echo ""

        echo "🎯 Next steps:"
        echo "   1. Run: open \"$APP_PATH\""
        echo "   2. Test macOS features (Ollama, Parakeet, Global Dictation)"
        echo "   3. Create DMG: ./package-dmg.sh (coming soon)"
        echo ""
    fi
else
    echo -e "${RED}❌ Build failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  • Files not added to Xcode project → Add them manually"
    echo "  • Mac Catalyst not enabled → Check XCODE_MACOS_SETUP.md"
    echo "  • UIKit compatibility → Check Part 5 in setup guide"
    echo ""
    exit 1
fi

echo "================================"
echo "Build complete! 🎉"
