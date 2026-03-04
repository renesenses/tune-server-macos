# tune-macos

Build & distribution tooling for [tune-server](https://github.com/renesenses/tune-server) on macOS.

## Installation

### Homebrew (recommended)

```bash
brew tap renesenses/tune https://github.com/renesenses/tune-macos
brew install tune-server
brew services start tune-server
```

Open http://localhost:8888

### Manual install

Download the latest release from [GitHub Releases](https://github.com/renesenses/tune-macos/releases).

```bash
tar xzf tune-server-*-macos-arm64.tar.gz
cd tune-server
cp .env.example .env    # edit as needed
./tune-server
```

#### Gatekeeper

The binary is not signed. If macOS blocks it:

```bash
xattr -cr ./tune-server
```

#### Launchd (auto-start without Homebrew)

```bash
mkdir -p ~/Library/LaunchAgents
cp extras/com.renesenses.tune-server.plist ~/Library/LaunchAgents/

# Edit paths in the plist to match your install location, then:
launchctl load ~/Library/LaunchAgents/com.renesenses.tune-server.plist
```

## Configuration

Environment variables (set in `.env` or shell):

| Variable | Default | Description |
|---|---|---|
| `TUNE_MUSIC_DIRS` | `~/Music` | Music library directories (comma-separated) |
| `TUNE_WEB_DIR` | `./web` | Web UI directory |
| `TUNE_DB_PATH` | `./tune_server.db` | SQLite database path |
| `TUNE_ARTWORK_CACHE_DIR` | `./artwork_cache` | Artwork cache directory |
| `TUNE_FFMPEG_PATH` | `ffmpeg` | Path to FFmpeg binary |
| `TUNE_FFPROBE_PATH` | `ffprobe` | Path to FFprobe binary |

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon (arm64) — Intel builds are possible but not pre-built
- FFmpeg (`brew install ffmpeg` — bundled in manual install)

## Building from source

```bash
git clone https://github.com/renesenses/tune-macos.git
cd tune-macos
./build.sh v0.1.0
```

The build script clones tune-server and tune-web-client, builds the web UI, creates a Python venv, runs PyInstaller, and packages everything into a `.tar.gz`.

Environment variables for the build:

| Variable | Default | Description |
|---|---|---|
| `TUNE_SERVER_REF` | `main` | Git ref for tune-server |
| `TUNE_WEB_REF` | `main` | Git ref for tune-web-client |
| `SKIP_WEB` | `0` | Set to `1` to skip web client build |
| `SKIP_FFMPEG` | `0` | Set to `1` to skip FFmpeg bundling |

## Updating

```bash
brew upgrade tune-server
brew services restart tune-server
```

## Uninstalling

```bash
brew services stop tune-server
brew uninstall tune-server
brew untap renesenses/tune
# Data remains in /opt/homebrew/var/tune-server/ — delete manually if needed
```
