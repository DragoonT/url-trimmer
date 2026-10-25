# -*- mode: python ; coding: utf-8 -*-
# Headless server sidecar for the Tauri desktop shell.
#
# Build:  python -m PyInstaller --clean --noconfirm TrimPlaylistServer.spec
# Output: dist/TrimPlaylistServer/TrimPlaylistServer(.exe) + _internal/
#
# The Tauri app bundles this folder under src-tauri/resources/server/ and
# spawns TrimPlaylistServer at startup (see src-tauri/src/lib.rs). The console
# stays enabled so the TRIM_SERVER_READY line reaches Tauri over stdout; the
# shell spawns it with CREATE_NO_WINDOW so nothing flashes on screen.
from pathlib import Path
import sys

from PyInstaller.utils.hooks import collect_data_files, collect_submodules

ROOT = Path(SPECPATH)
WINDOWS_ICON = ROOT / "denia.ico"

datas = [(str(ROOT / "player"), "player")]
if (ROOT / "denia.ico").is_file():
    datas.append((str(ROOT / "denia.ico"), "."))
datas += collect_data_files("imageio_ffmpeg")

a = Analysis(
    ["pc/app/trim_playlist_server_main.py"],
    pathex=[str(ROOT)],
    binaries=[],
    datas=datas,
    hiddenimports=["imageio_ffmpeg"] + collect_submodules("yt_dlp"),
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["webview"],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="TrimPlaylistServer",
    icon=str(WINDOWS_ICON) if sys.platform == "win32" and WINDOWS_ICON.is_file() else None,
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="TrimPlaylistServer",
)
