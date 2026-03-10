"""Tests to verify all required files are present for PyInstaller builds.

These tests catch missing data files (like schema.sql) BEFORE building,
so we never ship a broken bundle again.

Run: python -m pytest tests/ -v
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = PROJECT_ROOT / "src" / "tune-server"
SPEC_FILE = PROJECT_ROOT / "tune-server.spec"

# Files that MUST be bundled by PyInstaller
REQUIRED_DATA_FILES = [
    "tune_server/db/schema.sql",
]


# ---------------------------------------------------------------------------
# Source data files
# ---------------------------------------------------------------------------

class TestDataFilesExist:
    """Verify required data files exist in the source checkout."""

    @pytest.mark.skipif(not SRC_DIR.exists(), reason="src/ not checked out")
    @pytest.mark.parametrize("rel_path", REQUIRED_DATA_FILES)
    def test_required_data_file_exists(self, rel_path: str):
        path = SRC_DIR / rel_path
        assert path.is_file(), f"Required data file missing: {path}"

    @pytest.mark.skipif(not SRC_DIR.exists(), reason="src/ not checked out")
    @pytest.mark.parametrize("rel_path", REQUIRED_DATA_FILES)
    def test_required_data_file_not_empty(self, rel_path: str):
        path = SRC_DIR / rel_path
        assert path.stat().st_size > 0, f"Required data file is empty: {path}"


# ---------------------------------------------------------------------------
# Schema SQL content
# ---------------------------------------------------------------------------

class TestSchemaSQL:
    """Verify schema.sql contains expected tables."""

    @pytest.mark.skipif(not SRC_DIR.exists(), reason="src/ not checked out")
    def test_schema_contains_core_tables(self):
        schema = (SRC_DIR / "tune_server" / "db" / "schema.sql").read_text()
        for table in ["artists", "albums", "tracks", "zones", "playlists"]:
            assert f"CREATE TABLE IF NOT EXISTS {table}" in schema, (
                f"schema.sql missing table: {table}"
            )

    @pytest.mark.skipif(not SRC_DIR.exists(), reason="src/ not checked out")
    def test_engine_references_schema_correctly(self):
        engine_py = SRC_DIR / "tune_server" / "db" / "engine.py"
        content = engine_py.read_text()
        assert 'Path(__file__).parent / "schema.sql"' in content, (
            "engine.py must load schema.sql relative to __file__"
        )


# ---------------------------------------------------------------------------
# PyInstaller spec
# ---------------------------------------------------------------------------

class TestPyInstallerSpec:
    """Verify the .spec bundles all required data files."""

    def test_spec_file_exists(self):
        assert SPEC_FILE.is_file(), "tune-server.spec missing"

    def test_spec_includes_schema_sql(self):
        content = SPEC_FILE.read_text()
        assert "schema.sql" in content, (
            "tune-server.spec must include schema.sql in datas"
        )

    def test_spec_includes_certifi(self):
        content = SPEC_FILE.read_text()
        assert "certifi" in content, (
            "tune-server.spec must bundle certifi CA certs for HTTPS"
        )

    def test_spec_includes_sounddevice(self):
        content = SPEC_FILE.read_text()
        assert "sounddevice" in content, (
            "tune-server.spec must bundle sounddevice/portaudio"
        )

    @pytest.mark.skipif(not SRC_DIR.exists(), reason="src/ not checked out")
    def test_all_spec_data_paths_exist(self):
        """Verify every file explicitly listed in datas exists in source."""
        content = SPEC_FILE.read_text()
        # Match: (str(SRC / "path" / "to" / "file.ext"), "dest")
        for match in re.finditer(r'str\(SRC\s*/\s*"([^"]+)"(?:\s*/\s*"([^"]+)")*', content):
            parts = [g for g in match.groups() if g is not None]
            rel_path = "/".join(parts)
            assert (SRC_DIR / rel_path).exists(), (
                f"Spec references missing source file: {rel_path}"
            )


# ---------------------------------------------------------------------------
# Build script
# ---------------------------------------------------------------------------

class TestBuildScript:
    """Verify build.sh is present and correct."""

    def test_build_script_exists(self):
        assert (PROJECT_ROOT / "build.sh").is_file(), "build.sh missing"

    def test_build_script_is_executable(self):
        import os
        assert os.access(PROJECT_ROOT / "build.sh", os.X_OK), (
            "build.sh must be executable"
        )

    def test_build_script_bundles_web_dir(self):
        content = (PROJECT_ROOT / "build.sh").read_text()
        assert "web" in content, "build.sh must copy web/ into the bundle"

    def test_build_script_bundles_ffmpeg(self):
        content = (PROJECT_ROOT / "build.sh").read_text()
        assert "ffmpeg" in content, "build.sh must copy ffmpeg into the bundle"


# ---------------------------------------------------------------------------
# Database init (requires source checkout)
# ---------------------------------------------------------------------------

class TestDatabaseInit:
    """Verify schema.sql actually works in SQLite."""

    @pytest.mark.skipif(not SRC_DIR.exists(), reason="src/ not checked out")
    @pytest.mark.asyncio
    async def test_database_connects_and_creates_tables(self):
        import sys
        sys.path.insert(0, str(SRC_DIR))
        try:
            from tune_server.db.engine import Database

            db = Database(":memory:")
            await db.connect()

            cursor = await db.execute(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            )
            rows = await cursor.fetchall()
            table_names = {row[0] for row in rows}

            for expected in ["artists", "albums", "tracks", "zones", "playlists"]:
                assert expected in table_names, (
                    f"Table {expected} not created by schema.sql"
                )

            await db.close()
        finally:
            sys.path.pop(0)
