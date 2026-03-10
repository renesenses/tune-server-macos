#!/usr/bin/env bash
#
# build.sh — Build a self-contained tune-server distribution for macOS.
#
# Usage:
#   ./build.sh [VERSION]
#
# Environment variables:
#   TUNE_SERVER_REF   git ref for tune-server  (default: main)
#   TUNE_WEB_REF      git ref for tune-web-client (default: main)
#   SKIP_WEB          set to 1 to skip web client build
#   SKIP_FFMPEG       set to 1 to skip FFmpeg bundling (use Homebrew at runtime)

set -euo pipefail

VERSION="${1:-dev}"
ARCH="$(uname -m)"  # arm64 or x86_64
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
SRC_DIR="$SCRIPT_DIR/src"

TUNE_SERVER_REF="${TUNE_SERVER_REF:-main}"
TUNE_WEB_REF="${TUNE_WEB_REF:-main}"

echo "==> Building tune-server $VERSION for macOS $ARCH"

# ---------- 0. Find Python 3.11+ ---------------------------------------------

PYTHON=""
for py in python3.14 python3.13 python3.12 python3.11 python3; do
    if command -v "$py" &>/dev/null; then
        PY_VER=$("$py" -c "import sys; print(sys.version_info.minor)")
        if [ "$PY_VER" -ge 11 ] 2>/dev/null; then
            PYTHON="$py"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python 3.11+ required. Install it:"
    echo "  brew install python@3.14"
    exit 1
fi

echo "    Python: $($PYTHON --version)"

# ---------- 1. Clone sources --------------------------------------------------

mkdir -p "$SRC_DIR"

if [ ! -d "$SRC_DIR/tune-server" ]; then
    echo "==> Cloning tune-server ($TUNE_SERVER_REF)..."
    git clone --depth 1 --branch "$TUNE_SERVER_REF" \
        https://github.com/renesenses/tune-server-linux.git "$SRC_DIR/tune-server"
else
    echo "==> Updating tune-server..."
    cd "$SRC_DIR/tune-server" && git fetch && git checkout "$TUNE_SERVER_REF" && git pull || true
    cd "$SCRIPT_DIR"
fi

if [ "${SKIP_WEB:-0}" != "1" ]; then
    if [ ! -d "$SRC_DIR/tune-web-client" ]; then
        echo "==> Cloning tune-web-client ($TUNE_WEB_REF)..."
        git clone --depth 1 --branch "$TUNE_WEB_REF" \
            https://github.com/renesenses/tune-web-client.git "$SRC_DIR/tune-web-client"
    else
        echo "==> Updating tune-web-client..."
        cd "$SRC_DIR/tune-web-client" && git fetch && git checkout "$TUNE_WEB_REF" && git pull || true
        cd "$SCRIPT_DIR"
    fi
fi

# ---------- 2. Build web client -----------------------------------------------

WEB_DIST="$SRC_DIR/tune-web-client/dist"
if [ "${SKIP_WEB:-0}" != "1" ]; then
    echo "==> Building web client..."
    cd "$SRC_DIR/tune-web-client"
    npm ci
    npx vite build
    cd "$SCRIPT_DIR"
else
    echo "==> Skipping web client build"
fi

# ---------- 3. Python venv + deps ---------------------------------------------

VENV="$BUILD_DIR/venv"
echo "==> Setting up Python venv..."
"$PYTHON" -m venv "$VENV"
source "$VENV/bin/activate"

pip install --upgrade pip
pip install -r "$SRC_DIR/tune-server/requirements.txt" 2>/dev/null \
    || pip install -e "$SRC_DIR/tune-server"
pip install pyinstaller

# ---------- 4. PyInstaller build ----------------------------------------------

echo "==> Running PyInstaller..."
pyinstaller --clean --noconfirm "$SCRIPT_DIR/tune-server.spec"

# ---------- 5. Assemble distribution ------------------------------------------

STAGE="$BUILD_DIR/stage/tune-server"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# PyInstaller output
cp -R "$SCRIPT_DIR/dist/tune-server/"* "$STAGE/"

# Web UI
if [ -d "$WEB_DIST" ]; then
    mkdir -p "$STAGE/web"
    cp -R "$WEB_DIST/"* "$STAGE/web/"
fi

# Launchd plist
mkdir -p "$STAGE/extras"
cp "$SCRIPT_DIR/launchd/com.renesenses.tune-server.plist" "$STAGE/extras/"

# Example .env
cat > "$STAGE/.env.example" <<'ENVEOF'
# tune-server configuration
# Copy to .env and adjust as needed.

# Music library directories (comma-separated)
TUNE_MUSIC_DIRS=~/Music

# Web UI directory (auto-detected next to binary)
# TUNE_WEB_DIR=./web

# Database path
# TUNE_DB_PATH=./tune_server.db

# Artwork cache
# TUNE_ARTWORK_CACHE_DIR=./artwork_cache

# FFmpeg (auto-detected next to binary, falls back to PATH)
# TUNE_FFMPEG_PATH=ffmpeg
# TUNE_FFPROBE_PATH=ffprobe
ENVEOF

# ---------- 6. Bundle FFmpeg --------------------------------------------------

if [ "${SKIP_FFMPEG:-0}" != "1" ]; then
    echo "==> Bundling FFmpeg..."
    FFMPEG_BIN="$(which ffmpeg 2>/dev/null || true)"
    FFPROBE_BIN="$(which ffprobe 2>/dev/null || true)"

    if [ -n "$FFMPEG_BIN" ] && [ -n "$FFPROBE_BIN" ]; then
        cp "$FFMPEG_BIN" "$STAGE/ffmpeg"
        cp "$FFPROBE_BIN" "$STAGE/ffprobe"
        chmod +x "$STAGE/ffmpeg" "$STAGE/ffprobe"

        # Patch dylib rpaths to be self-contained
        _patch_dylibs() {
            local bin="$1"
            local libdir="$STAGE/lib"
            mkdir -p "$libdir"

            otool -L "$bin" | awk '/\/opt\/homebrew|\/usr\/local/{print $1}' | while read -r dylib; do
                local name
                name="$(basename "$dylib")"
                if [ ! -f "$libdir/$name" ]; then
                    cp "$dylib" "$libdir/$name" 2>/dev/null || true
                fi
                install_name_tool -change "$dylib" "@executable_path/lib/$name" "$bin" 2>/dev/null || true
            done
        }

        _patch_dylibs "$STAGE/ffmpeg"
        _patch_dylibs "$STAGE/ffprobe"

        # Also patch copied dylibs themselves
        if [ -d "$STAGE/lib" ]; then
            for dylib in "$STAGE/lib"/*.dylib; do
                [ -f "$dylib" ] || continue
                otool -L "$dylib" | awk '/\/opt\/homebrew|\/usr\/local/{print $1}' | while read -r dep; do
                    depname="$(basename "$dep")"
                    if [ ! -f "$STAGE/lib/$depname" ]; then
                        cp "$dep" "$STAGE/lib/$depname" 2>/dev/null || true
                    fi
                    install_name_tool -change "$dep" "@loader_path/$depname" "$dylib" 2>/dev/null || true
                done
            done
        fi

        echo "    FFmpeg bundled successfully."
    else
        echo "    WARNING: FFmpeg not found. Install via 'brew install ffmpeg' at runtime."
    fi
else
    echo "==> Skipping FFmpeg bundling"
fi

# ---------- 7. Create archive -------------------------------------------------

mkdir -p "$DIST_DIR"
ARCHIVE_NAME="tune-server-${VERSION}-macos-${ARCH}.tar.gz"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"

echo "==> Creating archive: $ARCHIVE_NAME"
cd "$BUILD_DIR/stage"
tar -czf "$ARCHIVE_PATH" tune-server/
cd "$SCRIPT_DIR"

# SHA256
shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}' > "$ARCHIVE_PATH.sha256"
SHA256="$(cat "$ARCHIVE_PATH.sha256")"

echo ""
echo "=== Build complete ==="
echo "  Archive : $ARCHIVE_PATH"
echo "  SHA256  : $SHA256"
echo "  Size    : $(du -h "$ARCHIVE_PATH" | awk '{print $1}')"

deactivate 2>/dev/null || true
