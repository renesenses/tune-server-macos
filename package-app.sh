#!/usr/bin/env bash
#
# package-app.sh — Package tune-server into a macOS .app bundle for TestFlight.
#
# Usage:
#   ./package-app.sh [VERSION]
#
# Prerequisites:
#   - Run ./build.sh first to create the tune-server binary
#   - Apple Distribution certificate in keychain
#   - Provisioning profile installed

set -euo pipefail

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"

TEAM_ID="VV3696M7PL"
BUNDLE_ID="com.renesenses.tune-server"
APP_NAME="Tune Server"
SIGNING_IDENTITY="Apple Distribution: Bertrand Clech (VV3696M7PL)"

STAGE_DIR="$SCRIPT_DIR/build/stage/tune-server"
APP_DIR="$SCRIPT_DIR/build/${APP_NAME}.app"
EXPORT_DIR="$SCRIPT_DIR/build/export"

echo "==> Packaging ${APP_NAME} v${VERSION} (build ${BUILD_NUMBER}) for macOS ${ARCH}"

# ---------- 1. Verify build exists -------------------------------------------

if [ ! -d "$STAGE_DIR" ]; then
    echo "ERROR: Build not found at $STAGE_DIR"
    echo "Run ./build.sh first."
    exit 1
fi

# ---------- 2. Find provisioning profile -------------------------------------

PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
PROFILE_PATH=""
for p in "$PROFILE_DIR"/*.provisionprofile; do
    [ -f "$p" ] || continue
    NAME=$(security cms -D -i "$p" 2>/dev/null | plutil -extract Name raw - 2>/dev/null || true)
    if [[ "$NAME" == *"Tune Server"* ]]; then
        PROFILE_PATH="$p"
        PROFILE_UUID=$(basename "$p" .provisionprofile)
        break
    fi
done

if [ -z "$PROFILE_PATH" ]; then
    echo "ERROR: Provisioning profile not found."
    echo "Install Tune_Server_Distribution.provisionprofile first."
    exit 1
fi
echo "    Profile: $PROFILE_PATH"

# ---------- 3. Create .app bundle structure ----------------------------------

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Put real binary + _internal in Resources (PyInstaller needs them together)
cp "$STAGE_DIR/tune-server" "$APP_DIR/Contents/Resources/tune-server-bin"
if [ -d "$STAGE_DIR/_internal" ]; then
    ditto "$STAGE_DIR/_internal" "$APP_DIR/Contents/Resources/_internal"
fi

# Copy ffmpeg/ffprobe and their dylibs to MacOS
for bin in ffmpeg ffprobe; do
    [ -f "$STAGE_DIR/$bin" ] && cp "$STAGE_DIR/$bin" "$APP_DIR/Contents/MacOS/$bin"
done
if [ -d "$STAGE_DIR/lib" ]; then
    mkdir -p "$APP_DIR/Contents/MacOS/lib"
    cp "$STAGE_DIR/lib/"*.dylib "$APP_DIR/Contents/MacOS/lib/" 2>/dev/null || true
fi

# Compile and install Mach-O launcher as the CFBundleExecutable
echo "    Compiling launcher..."
clang -arch arm64 -mmacosx-version-min=13.0 \
    -o "$APP_DIR/Contents/MacOS/tune-server" \
    "$SCRIPT_DIR/launcher.c" 2>/dev/null
chmod +x "$APP_DIR/Contents/MacOS/tune-server"

# Keep Python.framework in _internal (PyInstaller looks for it next to the binary)
# No need to move to Contents/Frameworks when binary is in Resources
echo "    Python.framework kept in _internal"

# Copy other resources
[ -d "$STAGE_DIR/web" ] && cp -R "$STAGE_DIR/web" "$APP_DIR/Contents/Resources/web"
[ -d "$STAGE_DIR/extras" ] && cp -R "$STAGE_DIR/extras" "$APP_DIR/Contents/Resources/extras"
[ -f "$STAGE_DIR/.env.example" ] && cp "$STAGE_DIR/.env.example" "$APP_DIR/Contents/Resources/.env.example"

# ---------- 4. Create Info.plist ---------------------------------------------

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>fr</string>
    <key>CFBundleExecutable</key>
    <string>tune-server</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "    Info.plist created"

# ---------- 5. Embed provisioning profile ------------------------------------

cp "$PROFILE_PATH" "$APP_DIR/Contents/embedded.provisionprofile"
echo "    Provisioning profile embedded"

# ---------- 6. Create entitlements -------------------------------------------

ENTITLEMENTS="$SCRIPT_DIR/build/entitlements.plist"
cat > "$ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.application-identifier</key>
    <string>VV3696M7PL.com.renesenses.tune-server</string>
    <key>com.apple.developer.team-identifier</key>
    <string>VV3696M7PL</string>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.assets.music.read-only</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
PLIST

echo "    Entitlements created"

# Separate entitlements for helper binaries (no app-identifier)
HELPER_ENTITLEMENTS="$SCRIPT_DIR/build/helper-entitlements.plist"
cat > "$HELPER_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.inherit</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
PLIST

# ---------- 7. Add icon before signing ---------------------------------------

ICNS_PATH="$SCRIPT_DIR/build/AppIcon.icns"
if [ -f "$ICNS_PATH" ]; then
    cp "$ICNS_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "    Icon added"
fi

# ---------- 8. Code sign -----------------------------------------------------

echo "==> Signing with: $SIGNING_IDENTITY"

# Remove quarantine attribute from all files (ignore errors from symlinks)
xattr -cr "$APP_DIR" 2>/dev/null || true
echo "    Quarantine attributes removed"

# Clean up metadata directories that confuse codesign
find "$APP_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find "$APP_DIR" -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
find "$APP_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Resolve symlinks to real files EXCEPT inside .framework bundles
echo "    Resolving symlinks..."
find "$APP_DIR" -type l | while read -r link; do
    # Skip symlinks inside .framework directories (Apple requires them)
    case "$link" in
        *.framework*) continue ;;
    esac
    target=$(readlink -f "$link" 2>/dev/null || python3 -c "import os; print(os.path.realpath('$link'))")
    if [ -f "$target" ]; then
        rm "$link"
        cp "$target" "$link"
    else
        rm "$link"
    fi
done

# Python.framework structure preserved by ditto (symlinks intact in Resources)
echo "    Python.framework structure OK"

# Rename .dylibs directories to _dylibs to avoid bundle confusion
find "$APP_DIR" -type d -name ".dylibs" | while read -r d; do
    parent="$(dirname "$d")"
    mv "$d" "${parent}/_dylibs"
done

# Sign Python.framework in _internal
echo "    Signing Python.framework..."
PY_FW="$APP_DIR/Contents/Resources/_internal/Python.framework"
if [ -d "$PY_FW" ]; then
    PY_VER=$(ls "$PY_FW/Versions/" 2>/dev/null | grep -v Current | head -1)
    if [ -n "$PY_VER" ]; then
        codesign --force --options runtime --timestamp \
            --sign "$SIGNING_IDENTITY" \
            "$PY_FW/Versions/$PY_VER/Python"
        codesign --force --options runtime --timestamp \
            --sign "$SIGNING_IDENTITY" \
            "$PY_FW"
    fi
fi

# Sign all Mach-O binaries in Resources/_internal and tune-server-bin
echo "    Signing libraries and binaries in _internal..."
codesign --force --timestamp \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$HELPER_ENTITLEMENTS" \
    "$APP_DIR/Contents/Resources/tune-server-bin" 2>/dev/null || true
find "$APP_DIR/Contents/Resources/_internal" -type f 2>/dev/null | while read -r f; do
    file_type=$(file -b "$f" 2>/dev/null)
    if [[ "$file_type" == *"Mach-O"* ]]; then
        codesign --force --timestamp \
            --sign "$SIGNING_IDENTITY" \
            "$f" 2>/dev/null || true
    fi
done

# Sign ffmpeg dylibs first
echo "    Signing ffmpeg dylibs..."
for dylib in "$APP_DIR/Contents/MacOS/lib/"*.dylib; do
    [ -f "$dylib" ] && codesign --force --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$dylib" 2>/dev/null || true
done

# Sign helper executables WITHOUT hardened runtime (ffmpeg crashes with it)
echo "    Signing helper executables..."
for bin in "$APP_DIR/Contents/MacOS/ffmpeg" "$APP_DIR/Contents/MacOS/ffprobe"; do
    [ -f "$bin" ] && codesign --force --timestamp \
        --sign "$SIGNING_IDENTITY" \
        --entitlements "$HELPER_ENTITLEMENTS" \
        "$bin" 2>/dev/null || true
done

# Sign the main app bundle (without --deep to avoid subcomponent issues)
echo "    Signing app bundle..."
codesign --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    "$APP_DIR"

echo "    App signed"

# Verify
codesign --verify --deep --strict "$APP_DIR" 2>&1 && echo "    Signature verified OK" || echo "    WARNING: Signature verification issues"

# ---------- 9. Create .pkg for upload ----------------------------------------

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

PKG_PATH="$EXPORT_DIR/TuneServer-${VERSION}.pkg"

productbuild \
    --component "$APP_DIR" /Applications \
    --sign "3rd Party Mac Developer Installer: Bertrand Clech (VV3696M7PL)" \
    "$PKG_PATH"

echo ""
echo "=== Packaging complete ==="
echo "  App : $APP_DIR"
echo "  Pkg : $PKG_PATH"
echo ""
echo "Next: ./upload-testflight.sh"
