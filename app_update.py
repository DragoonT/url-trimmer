"""Ask before replacing this copy when latest.json is a newer version."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
import urllib.request

APP_VERSION = "0.1.0"
LATEST_URL = "https://dragoont.github.io/url-trimmer/latest.json"


def _parts(value: str) -> tuple[int, ...]:
    numbers = []
    for piece in value.split("."):
        digits = "".join(ch for ch in piece if ch.isdigit())
        numbers.append(int(digits) if digits else 0)
    return tuple(numbers)


def is_newer(remote: str, local: str = APP_VERSION) -> bool:
    left, right = _parts(remote), _parts(local)
    width = max(len(left), len(right))
    left += (0,) * (width - len(left))
    right += (0,) * (width - len(right))
    return left > right


def package_key() -> str:
    if sys.platform == "win32":
        return "windows"
    if sys.platform.startswith("linux"):
        try:
            text = open("/etc/os-release", encoding="utf-8").read()
        except OSError:
            text = ""
        if "ID=nixos" in text:
            return "other"
        return "linux"
    return "other"


def _fetch() -> dict | None:
    request = urllib.request.Request(LATEST_URL, headers={"User-Agent": "TrimPlaylist"})
    with urllib.request.urlopen(request, timeout=8) as response:
        data = json.loads(response.read().decode("utf-8"))
    if not isinstance(data, dict):
        return None
    return data


def _download(url: str) -> str:
    name = url.rsplit("/", 1)[-1] or "TrimPlaylist-update"
    folder = os.path.join(tempfile.gettempdir(), "TrimPlaylist-update")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name)
    request = urllib.request.Request(url, headers={"User-Agent": "TrimPlaylist"})
    with urllib.request.urlopen(request, timeout=120) as response, open(path, "wb") as handle:
        while True:
            chunk = response.read(1024 * 256)
            if not chunk:
                break
            handle.write(chunk)
    return path


def _open_file(path: str) -> None:
    if sys.platform == "win32":
        os.startfile(path)  # type: ignore[attr-defined]
        return
    if sys.platform == "darwin":
        subprocess.Popen(["open", path])
        return
    subprocess.Popen(["xdg-open", path])


def offer_update(window) -> None:
    try:
        data = _fetch()
    except Exception:
        return
    if not data:
        return
    version = str(data.get("version") or "")
    url = str(data.get(package_key()) or "")
    if not version or not url or not is_newer(version):
        return
    if package_key() == "windows":
        detail = "The installer opens next. Confirm it to replace this copy."
    elif package_key() == "linux":
        detail = "The new .tar.gz opens next. Close Trim Playlist, then unpack it over this folder."
    else:
        detail = "The new zip opens next. Close Trim Playlist, then unpack it over this folder."
    agreed = window.create_confirmation_dialog(
        "Update",
        f"Version {version} is ready.\n\n{detail}",
    )
    if not agreed:
        return

    def work() -> None:
        try:
            path = _download(url)
            _open_file(path)
        except Exception as exc:
            window.create_confirmation_dialog("Update", f"The download did not finish.\n\n{exc}")

    threading.Thread(target=work, daemon=True).start()
