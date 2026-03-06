#!/usr/bin/env bash
#
# run-from-source.sh — Clone, build and run tune-server from sources.
#
# Usage:
#   ./run-from-source.sh
#
# Prerequisites:
#   - Python 3.11+ (brew install python)
#   - Node.js 18+  (brew install node)
#   - FFmpeg        (brew install ffmpeg)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"

# ---------- 1. Check prerequisites -------------------------------------------

echo "==> Checking prerequisites..."

for cmd in python3 node npm ffmpeg ffprobe; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Install it first:"
        echo "  brew install python node ffmpeg"
        exit 1
    fi
done

echo "    Python:  $(python3 --version)"
echo "    Node:    $(node --version)"
echo "    FFmpeg:  $(ffmpeg -version 2>&1 | head -1)"

# ---------- 2. Clone / update sources ----------------------------------------

mkdir -p "$SRC_DIR"

if [ ! -d "$SRC_DIR/tune-server" ]; then
    echo "==> Cloning tune-server..."
    git clone --depth 1 https://github.com/renesenses/tune-server.git "$SRC_DIR/tune-server"
else
    echo "==> Updating tune-server..."
    cd "$SRC_DIR/tune-server" && git pull || true
    cd "$SCRIPT_DIR"
fi

if [ ! -d "$SRC_DIR/tune-web-client" ]; then
    echo "==> Cloning tune-web-client..."
    git clone --depth 1 https://github.com/renesenses/tune-web-client.git "$SRC_DIR/tune-web-client"
else
    echo "==> Updating tune-web-client..."
    cd "$SRC_DIR/tune-web-client" && git pull || true
    cd "$SCRIPT_DIR"
fi

# ---------- 3. Build web client -----------------------------------------------

echo "==> Building web client..."
cd "$SRC_DIR/tune-web-client"
npm ci
npx vite build
cd "$SCRIPT_DIR"

# ---------- 4. Python venv + deps ---------------------------------------------

VENV="$SCRIPT_DIR/build/venv-dev"
if [ ! -d "$VENV" ]; then
    echo "==> Creating Python venv..."
    python3 -m venv "$VENV"
fi

source "$VENV/bin/activate"
pip install --upgrade pip -q
pip install -r "$SRC_DIR/tune-server/requirements.txt" -q 2>/dev/null \
    || pip install -e "$SRC_DIR/tune-server" -q

# ---------- 5. Run tune-server ------------------------------------------------

echo ""
echo "==> Starting tune-server..."
echo "    Web UI:    http://localhost:8888"
echo "    Streaming: http://localhost:8080"
echo "    Press Ctrl+C to stop."
echo ""

export TUNE_WEB_DIR="$SRC_DIR/tune-web-client/dist"
export TUNE_MUSIC_DIRS="$HOME/Music"
export TUNE_FFMPEG_PATH="$(which ffmpeg)"
export TUNE_FFPROBE_PATH="$(which ffprobe)"

cd "$SRC_DIR/tune-server"
python -m tune_server
