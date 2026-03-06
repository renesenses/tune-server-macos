#!/usr/bin/env bash
#
# upload-testflight.sh — Upload the .pkg to App Store Connect for TestFlight.
#
# Usage:
#   ./upload-testflight.sh
#
# Prerequisites:
#   - Run ./package-app.sh first
#   - App Store Connect API key OR Apple ID credentials
#
# Environment variables (optional, will prompt if not set):
#   APPLE_ID          Apple ID email
#   APP_PASSWORD      App-specific password (generate at appleid.apple.com)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_DIR="$SCRIPT_DIR/build/export"

# Find the .pkg
PKG_PATH=$(ls -t "$EXPORT_DIR"/*.pkg 2>/dev/null | head -1)
if [ -z "$PKG_PATH" ]; then
    echo "ERROR: No .pkg found in $EXPORT_DIR"
    echo "Run ./package-app.sh first."
    exit 1
fi

echo "==> Uploading to App Store Connect: $(basename "$PKG_PATH")"

# ---------- Credentials ------------------------------------------------------

APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"

if [ -z "$APPLE_ID" ]; then
    echo -n "Apple ID (email): "
    read -r APPLE_ID
fi

if [ -z "$APP_PASSWORD" ]; then
    echo ""
    echo "You need an app-specific password."
    echo "Generate one at: https://account.apple.com/account/manage"
    echo "  -> Sign-In and Security -> App-Specific Passwords -> +"
    echo ""
    echo -n "App-specific password: "
    read -rs APP_PASSWORD
    echo ""
fi

# ---------- Upload -----------------------------------------------------------

echo "==> Uploading via xcrun notarytool / altool..."

# Try xcrun altool first (works for TestFlight upload)
xcrun altool --upload-app \
    --type macos \
    --file "$PKG_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    2>&1

RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "=== Upload successful ==="
    echo "The build will appear in TestFlight within 15-30 minutes"
    echo "after Apple's automated processing."
    echo ""
    echo "Check status at: https://appstoreconnect.apple.com/apps"
else
    echo ""
    echo "=== Upload failed ==="
    echo "Common fixes:"
    echo "  1. Generate an app-specific password at https://account.apple.com/account/manage"
    echo "  2. Make sure the app version/build number is unique"
    echo "  3. Check that the bundle ID matches App Store Connect"
    exit 1
fi
