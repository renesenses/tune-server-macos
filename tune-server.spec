# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec for tune-server (macOS arm64, onedir mode).

Usage:
    pyinstaller tune-server.spec
"""

import sys
from pathlib import Path
from PyInstaller.utils.hooks import (
    collect_data_files,
    collect_submodules,
    copy_metadata,
)

block_cipher = None

SRC = Path("src/tune-server")

# --- Hidden imports -----------------------------------------------------------

hidden_imports = [
    # FastAPI / Uvicorn internals
    *collect_submodules("uvicorn"),
    "uvicorn.lifespan.on",
    "uvicorn.lifespan.off",
    # Pydantic
    *collect_submodules("pydantic"),
    *collect_submodules("pydantic_settings"),
    # Streaming services
    *collect_submodules("tidalapi"),
    *collect_submodules("ytmusicapi"),
    *collect_submodules("yt_dlp"),
    *collect_submodules("spotipy"),
    *collect_submodules("deezer"),
    *collect_submodules("aiohttp"),
    # Discovery & playback
    *collect_submodules("pyatv"),
    *collect_submodules("async_upnp_client"),
    *collect_submodules("zeroconf"),
    # Audio & media
    "sounddevice",
    "_sounddevice_data",
    "numpy",
    *collect_submodules("mutagen"),
    *collect_submodules("PIL"),
    # Metadata providers
    "musicbrainzngs",
    *collect_submodules("discogs_client"),
    # Misc
    "watchfiles",
    "watchfiles._rust_notify",
    "multipart",
    "structlog",
    "aiosqlite",
    "certifi",
    "email.mime.text",
    "email.mime.multipart",
]

# --- Data files ---------------------------------------------------------------

datas = [
    # DB schema
    (str(SRC / "tune_server" / "db" / "schema.sql"), "tune_server/db"),
    # certifi CA bundle
    *collect_data_files("certifi"),
    # sounddevice portaudio dylib
    *collect_data_files("_sounddevice_data"),
    # yt-dlp extractors
    *collect_data_files("yt_dlp"),
    # pyatv protocol data
    *collect_data_files("pyatv"),
]

# --- Excludes -----------------------------------------------------------------

excludes = [
    "tkinter",
    "_tkinter",
    "matplotlib",
    "pytest",
    "test",
    "unittest",
    "doctest",
    "pdb",
    "IPython",
    "notebook",
    "sphinx",
]

# --- Analysis -----------------------------------------------------------------

a = Analysis(
    [str(SRC / "tune_server" / "__main__.py")],
    pathex=[str(SRC)],
    binaries=[],
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="tune-server",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    target_arch="arm64",
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    name="tune-server",
)
