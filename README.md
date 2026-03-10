# Tune Server — macOS Installation Guide

Multi-room audio server with DLNA/AirPlay output, streaming service integration, and web-based remote control.

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon (arm64) or Intel (x86_64)
- [Homebrew](https://brew.sh)

## Check your architecture

```bash
uname -m
```

- `arm64` → Apple Silicon (M1/M2/M3/M4) → follow "Apple Silicon" section
- `x86_64` → Intel → follow "Intel" section

## Download

Releases are available at **https://mozaiklabs.fr/download** — no GitHub account needed.

Alternatively, install via Homebrew (Apple Silicon only, see below).

## Installation (Apple Silicon)

```bash
brew tap renesenses/tune https://github.com/renesenses/tune-server-macos
brew install tune-server
brew services start tune-server
```

Open http://localhost:8888

## Installation (Intel)

Download the Intel archive from **https://mozaiklabs.fr/download**, then:

```bash
tar xzf tune-server-*-macos-x86_64.tar.gz
cd tune-server
./tune-server
```

Open http://localhost:8888

If no Intel archive is available yet, build from source:

```bash
# Prerequisites
brew install ffmpeg python@3.12 node

# Build and run
git clone https://github.com/renesenses/tune-server-macos.git
cd tune-server-macos
./build.sh v0.1.2
cd dist/tune-server
./tune-server
```

### If macOS blocks the binary (Gatekeeper)

```bash
xattr -cr ./tune-server
```

Or go to **System Settings > Privacy & Security** and click **Open Anyway**.

## Configuration

By default, Tune scans `~/Music`. No `.env` file is needed — web UI, FFmpeg, and FFprobe are auto-detected next to the binary.

To customize, create a `.env` file in the working directory:

```
TUNE_MUSIC_DIRS=["~/Music", "/Volumes/MyDrive/Music"]
TUNE_LOG_LEVEL=INFO
```

### All settings

| Variable | Default | Description |
|---|---|---|
| `TUNE_MUSIC_DIRS` | `["~/Music"]` | Music library directories (JSON array) |
| `TUNE_API_PORT` | `8888` | API / Web UI port |
| `TUNE_STREAM_PORT` | `8080` | Audio streaming port (for DLNA renderers) |
| `TUNE_DB_PATH` | `tune_server.db` | SQLite database path |
| `TUNE_ARTWORK_CACHE_DIR` | `artwork_cache` | Artwork cache directory |
| `TUNE_FFMPEG_PATH` | auto-detected | Path to FFmpeg binary |
| `TUNE_FFPROBE_PATH` | auto-detected | Path to FFprobe binary |
| `TUNE_WEB_DIR` | auto-detected | Path to the web UI |
| `TUNE_LOG_LEVEL` | `INFO` | Logging level (`DEBUG`, `INFO`, `WARNING`, `ERROR`) |

## Getting started

Once the server is running, open http://localhost:8888 in your browser.

1. **Create a zone** — A zone is an audio output (speakers, DAC, AirPlay device...). On first launch, no zone exists. Go to the zone panel and create one by selecting an available audio output (local soundcard, DLNA renderer, or AirPlay device).
2. **Browse your library** — Your `~/Music` folder is scanned automatically. Albums, artists, and tracks appear in the library.
3. **Play music** — Select a track or album and assign it to your zone. Playback starts immediately.
4. **Connect streaming services** (optional) — Go to Settings to link Tidal, Qobuz, Spotify, YouTube Music, or Deezer.

## Usage

- **Web UI**: http://localhost:8888
- **Audio devices**: DLNA and AirPlay speakers on the local network are discovered automatically
- **Streaming services**: Tidal, Qobuz, YouTube Music, Spotify, Deezer — configure from the web UI
- **Force device rescan**: `POST http://localhost:8888/api/v1/devices/scan`

## Useful commands

```bash
# Start the service
brew services start tune-server

# Stop the service
brew services stop tune-server

# Restart
brew services restart tune-server

# View logs
cat /opt/homebrew/var/log/tune-server.log

# Restart in debug mode
TUNE_LOG_LEVEL=DEBUG brew services restart tune-server
```

## Auto-start without Homebrew (launchd)

```bash
mkdir -p ~/Library/LaunchAgents
cp extras/com.renesenses.tune-server.plist ~/Library/LaunchAgents/

# Edit paths in the plist to match your install location, then:
launchctl load ~/Library/LaunchAgents/com.renesenses.tune-server.plist
```

## Building from source

```bash
git clone https://github.com/renesenses/tune-server-macos.git
cd tune-server-macos
./build.sh v0.1.2
```

The build script clones tune-server and tune-web-client, builds the Svelte web UI, creates a Python venv, runs PyInstaller, bundles FFmpeg, and packages everything into a `.tar.gz`.

### Build prerequisites

- Python 3.11+
- Node.js 18+
- FFmpeg (`brew install ffmpeg`)

### Build environment variables

| Variable | Default | Description |
|---|---|---|
| `TUNE_SERVER_REF` | `main` | Git ref for tune-server |
| `TUNE_WEB_REF` | `main` | Git ref for tune-web-client |
| `SKIP_WEB` | `0` | Set to `1` to skip web client build |
| `SKIP_FFMPEG` | `0` | Set to `1` to skip FFmpeg bundling |

## Updating

### Homebrew (Apple Silicon)

```bash
brew upgrade tune-server
brew services restart tune-server
```

### Intel / Manual

```bash
cd tune-server-macos
git pull
./build.sh v0.1.2
```

## Uninstalling

### Homebrew

```bash
brew services stop tune-server
brew uninstall tune-server
brew untap renesenses/tune
# Data remains in /opt/homebrew/var/tune-server/ — delete manually if needed
```

### Manual

```bash
launchctl unload ~/Library/LaunchAgents/com.renesenses.tune-server.plist 2>/dev/null
rm ~/Library/LaunchAgents/com.renesenses.tune-server.plist 2>/dev/null
rm -rf /path/to/tune-server/
```

## Troubleshooting

| Problem | Solution |
|---|---|
| macOS blocks the binary | `xattr -cr ./tune-server` or System Settings > Privacy & Security > Open Anyway |
| No devices found | Check that speakers are on the same Wi-Fi network |
| Port 8888 already in use | Add `TUNE_API_PORT=9999` to `.env` |
| FFmpeg not found | `brew install ffmpeg` |
| Web UI not showing (JSON response) | Set `TUNE_WEB_DIR=./web` in `.env` (should be auto-detected in v0.1.2+) |
| PortAudio crash on old Mac | Update to v0.1.2+ (auto-recovery added) |
