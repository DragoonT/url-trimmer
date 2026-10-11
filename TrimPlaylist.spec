# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path

from PyInstaller.utils.hooks import collect_data_files, collect_submodules

ROOT = Path(SPECPATH)
import runpy
runpy.run_path(str(ROOT / "package_extension.py"))["package_extension"](ROOT)

datas = [(str(ROOT / "player"), "player")]
datas += collect_data_files("imageio_ffmpeg")

a = Analysis(
    ["trim_playlist_app.py"],
    pathex=[str(ROOT)],
    binaries=[],
    datas=datas,
    hiddenimports=["imageio_ffmpeg", "webview", "clr"] + collect_submodules("yt_dlp"),
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="TrimPlaylist",
    icon=str(ROOT / "denia.jpg"),
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
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
    upx=True,
    upx_exclude=[],
    name="TrimPlaylist",
)
