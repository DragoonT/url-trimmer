"""Paths for normal Python runs and frozen .exe builds."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def is_frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def project_root() -> Path:
    """Folder that contains player/ and the pc package."""
    for parent in Path(__file__).resolve().parents:
        if (parent / "player").is_dir() and (parent / "pc" / "app" / "app_paths.py").is_file():
            return parent
    return Path(__file__).resolve().parent


def _is_project_root(path: Path) -> bool:
    return (path / "player").is_dir() and (path / "pc" / "server" / "playlist_server.py").is_file()


def find_project_root(start: Path) -> Path | None:
    current = start.resolve()
    for _ in range(8):
        if _is_project_root(current):
            return current
        parent = current.parent
        if parent == current:
            break
        current = parent
    return None


def app_dir() -> Path:
    """Writable app folder — playlists, session, output, cookies."""
    override = os.environ.get("TRIM_PLAYLIST_DIR", "").strip()
    if override:
        return Path(override).expanduser().resolve()

    if not is_frozen():
        return project_root()

    executable_dir = Path(sys.executable).resolve().parent
    # Preserve portable builds that already keep their data next to the app.
    # Installed apps must never try to write to Program Files.
    installed_root = find_project_root(executable_dir)
    if installed_root is not None:
        return installed_root
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", executable_dir))
        return base / "Trim Playlist"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Trim Playlist"
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return base / "trim-playlist"


def resource_dir() -> Path:
    """Bundled read-only assets (player UI, ffmpeg binaries)."""
    if is_frozen():
        bundle = getattr(sys, "_MEIPASS", None)
        if bundle:
            return Path(bundle)
    return project_root()


def hidden_subprocess_kwargs() -> dict[str, object]:
    """Prevent ffmpeg and other tools from flashing a console on Windows."""
    if sys.platform != "win32":
        return {}
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = subprocess.SW_HIDE
    return {
        "creationflags": subprocess.CREATE_NO_WINDOW,
        "startupinfo": startupinfo,
    }


def run_hidden(*args, **kwargs):
    kwargs.update(hidden_subprocess_kwargs())
    return subprocess.run(*args, **kwargs)


def install_hidden_subprocess() -> None:
    """Patch subprocess so all child processes stay hidden (for .exe builds)."""
    if sys.platform != "win32":
        return
    if getattr(subprocess, "_trim_playlist_hidden", False):
        return
    subprocess._trim_playlist_hidden = True

    create_no_window = subprocess.CREATE_NO_WINDOW
    startf_useshowwindow = subprocess.STARTF_USESHOWWINDOW
    sw_hide = subprocess.SW_HIDE
    original_run = subprocess.run
    original_popen = subprocess.Popen

    def apply_hidden(kwargs: dict) -> dict:
        kwargs["creationflags"] = kwargs.get("creationflags", 0) | create_no_window
        startupinfo = kwargs.get("startupinfo")
        if startupinfo is None:
            startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= startf_useshowwindow
        startupinfo.wShowWindow = sw_hide
        kwargs["startupinfo"] = startupinfo
        return kwargs

    def run(*args, **kwargs):
        return original_run(*args, **apply_hidden(kwargs))

    class HiddenPopen(original_popen):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **apply_hidden(kwargs))

    subprocess.run = run  # type: ignore[assignment]
    subprocess.Popen = HiddenPopen  # type: ignore[assignment]


install_hidden_subprocess()
