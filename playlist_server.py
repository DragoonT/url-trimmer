from __future__ import annotations

import argparse
import json
import mimetypes
import re
import shutil
import socket
import subprocess
import threading
import time
import urllib.error
import urllib.request
import uuid
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

from app_paths import app_dir, resource_dir, run_hidden
from download_jobs import start_download, get_job
import account_connections

QUALITY_HEIGHTS = (1080, 720, 480, 360)

SCRIPT_DIR = app_dir()
PLAYER_DIR = resource_dir() / "player"
PLAYLISTS_DIR = SCRIPT_DIR / "playlists"
SESSION_FILE = SCRIPT_DIR / "player-session.json"
MEDIA_EXTENSIONS = {".mp3", ".mp4", ".m4a", ".webm", ".ogg", ".wav", ".flac", ".mkv"}

DEFAULT_PLAYER_SESSION = {
    "playlistId": None,
    "trackId": None,
    "currentTime": 0,
    "wasPlaying": False,
    "shuffle": False,
    "repeat": "off",
    "volume": 100,
    "videoQuality": "original",
    "savedAt": 0,
}


def slugify(name: str) -> str:
    slug = re.sub(r"[^\w\s-]", "", name.strip().lower())
    slug = re.sub(r"[\s_-]+", "-", slug).strip("-")
    return slug or "playlist"


def media_kind(path: Path) -> str:
    return "video" if path.suffix.lower() in {".mp4", ".webm", ".mkv"} else "audio"


def find_ffmpeg() -> str | None:
    system_ffmpeg = shutil.which("ffmpeg")
    if system_ffmpeg:
        return system_ffmpeg
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return None


def probe_video_height(path: Path) -> int | None:
    ffmpeg = find_ffmpeg()
    if ffmpeg is None:
        return None
    try:
        result = run_hidden(
            [ffmpeg, "-hide_banner", "-i", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    output = f"{result.stderr}\n{result.stdout}"
    match = re.search(r"Video:.*?(\d{3,4})x(\d{3,4})", output)
    if not match:
        return None
    return int(match.group(2))


def build_quality_options(source_height: int | None) -> list[dict]:
    options: list[dict] = [
        {
            "id": "original",
            "label": f"Source ({source_height}p)" if source_height else "Source",
            "available": True,
        }
    ]
    for height in QUALITY_HEIGHTS:
        can_downscale = source_height is not None and height < source_height
        if can_downscale:
            label = f"{height}p"
        elif source_height and height >= source_height:
            label = f"{height}p — re-download needed"
        else:
            label = f"{height}p"
        options.append(
            {
                "id": str(height),
                "label": label,
                "available": can_downscale,
            }
        )
    return options


def transcode_cache_path(source: Path, height: int) -> Path:
    cache_dir = source.parent / ".transcode_cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir / f"{source.stem}_{height}p.mp4"


def transcode_to_height(source: Path, height: int) -> Path | None:
    ffmpeg = find_ffmpeg()
    if ffmpeg is None:
        return None
    dest = transcode_cache_path(source, height)
    if dest.exists() and dest.stat().st_mtime >= source.stat().st_mtime:
        return dest
    cmd = [
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(source),
        "-vf",
        f"scale=-2:{height}",
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "23",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        str(dest),
    ]
    try:
        run_hidden(cmd, check=True, capture_output=True)
    except (OSError, subprocess.CalledProcessError):
        if dest.exists():
            dest.unlink(missing_ok=True)
        return None
    return dest if dest.is_file() else None


def resolve_media_path(source: Path, quality: str) -> Path:
    if quality in ("", "original", "auto"):
        return source
    if not quality.isdigit():
        return source
    height = int(quality)
    if source.suffix.lower() not in {".mp4", ".webm", ".mkv"}:
        return source
    source_height = probe_video_height(source)
    if source_height is None or height >= source_height:
        return source
    transcoded = transcode_to_height(source, height)
    return transcoded or source


def resolve_item_path(playlist_id: str, item: dict) -> Path | None:
    if item.get("source") == "path":
        path = Path(item["path"]).expanduser()
        return path if path.is_file() else None
    rel = item.get("file", "")
    path = PLAYLISTS_DIR / playlist_id / rel
    return path if path.is_file() else None


def load_player_session() -> dict:
    if not SESSION_FILE.exists():
        return dict(DEFAULT_PLAYER_SESSION)
    try:
        data = json.loads(SESSION_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return dict(DEFAULT_PLAYER_SESSION)
    if not isinstance(data, dict):
        return dict(DEFAULT_PLAYER_SESSION)
    merged = dict(DEFAULT_PLAYER_SESSION)
    merged.update(data)
    return merged


def save_player_session(data: dict) -> dict:
    current = load_player_session()
    current.update(data)
    current["savedAt"] = int(time.time() * 1000)
    if current.get("repeat") not in ("off", "all", "one"):
        current["repeat"] = "off"
    try:
        volume = int(current.get("volume", 100))
        current["volume"] = max(0, min(100, volume))
    except (TypeError, ValueError):
        current["volume"] = 100
    try:
        current["currentTime"] = max(0.0, float(current.get("currentTime") or 0))
    except (TypeError, ValueError):
        current["currentTime"] = 0
    current["wasPlaying"] = bool(current.get("wasPlaying"))
    current["shuffle"] = bool(current.get("shuffle"))
    SESSION_FILE.write_text(
        json.dumps(current, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return current


class PlaylistHandler(SimpleHTTPRequestHandler):
    def account_request_allowed(self):
        host = urlparse('http://' + self.headers.get('Host', '')).hostname
        return self.client_address[0] in ('127.0.0.1', '::1') and host in ('127.0.0.1', 'localhost', '::1')

    def account_app_request_allowed(self):
        origin = self.headers.get('Origin')
        return self.account_request_allowed() and self.headers.get('X-Trim-Playlist') == '1' and (not origin or origin == 'http://' + self.headers.get('Host', ''))

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PLAYER_DIR), **kwargs)

    def log_message(self, format: str, *args) -> None:
        if args and isinstance(args[0], str) and "/api/" not in args[0]:
            super().log_message(format, *args)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        if path == '/api/accounts' or path.startswith('/api/accounts/pair/'):
            if not self.account_request_allowed():
                self.send_json({'error': 'Account connection is local only'}, 403)
                return
            try:
                data = account_connections.pairing(path.rsplit('/', 1)[-1]) if '/pair/' in path else account_connections.list_accounts()
                self.send_json(data)
            except ValueError as exc:
                self.send_json({'error': str(exc)}, 400)
            return

        if path == "/api/cookies":
            folder = SCRIPT_DIR / "cookies"
            names = sorted(p.name for p in folder.glob("*.txt") if p.is_file() and p.name.lower() != "readme.txt")
            self.send_json(names)
            return
        if path.startswith("/api/downloads/"):
            self.send_json(get_job(path.split("/")[-1]))
            return
        if path == "/api/playlists":
            self.send_json(list_playlists())
            return
        if path == "/api/session":
            self.send_json(load_player_session())
            return
        if path.startswith("/api/playlists/") and path.count("/") == 3:
            playlist_id = path.split("/")[-1]
            playlist = load_playlist(playlist_id)
            if playlist is None:
                self.send_json({"error": "Not found"}, 404)
                return
            self.send_json(playlist)
            return
        if path == "/api/media":
            params = parse_qs(parsed.query)
            playlist_id = params.get("playlist", [""])[0]
            item_id = params.get("item", [""])[0]
            quality = params.get("quality", ["original"])[0]
            self.serve_item(playlist_id, item_id, quality)
            return
        super().do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path == '/api/accounts/connect' or path.startswith('/api/accounts/pair/'):
            if not self.account_request_allowed() or (path == '/api/accounts/connect' and not self.account_app_request_allowed()):
                self.send_json({'error': 'Account connection request denied'}, 403)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if length < 0 or length > 1024 * 1024:
                    raise ValueError('Account request too large')
                data = self.read_json()
                if not isinstance(data, dict):
                    raise ValueError('Account request must be a JSON object')
                if path == '/api/accounts/connect':
                    result = {'token': account_connections.begin(data.get('platform'))}
                else:
                    result = account_connections.receive(path.rsplit('/', 1)[-1], data.get('cookies'), data.get('verified'))
                self.send_json(result)
            except (ValueError, TypeError) as exc:
                self.send_json({'error': str(exc)}, 400)
            return

        if path == "/api/downloads":
            try:
                job_id = start_download(self.read_json())
                self.send_json({"id": job_id}, 202)
            except (ValueError, TypeError) as exc:
                self.send_json({"error": str(exc)}, 400)
            return
        if path == "/api/playlists":
            data = self.read_json()
            playlist = create_playlist(str(data.get("name", "New playlist")))
            self.send_json(playlist, 201)
            return

        if path.startswith("/api/playlists/") and path.endswith("/items"):
            playlist_id = path.split("/")[3]
            content_type = self.headers.get("Content-Type", "")
            if content_type.startswith("multipart/form-data"):
                item = add_uploaded_item(playlist_id, self.rfile, self.headers, content_type)
            else:
                data = self.read_json()
                item = add_path_item(
                    playlist_id,
                    str(data.get("path", "")),
                    str(data.get("title", "")),
                )
            if item is None:
                self.send_json({"error": "Playlist not found or invalid file"}, 400)
                return
            self.send_json(item, 201)
            return

        self.send_error(404)

    def do_PUT(self) -> None:
        parsed = urlparse(self.path)
        parts = parsed.path.strip("/").split("/")
        if len(parts) == 2 and parts[0] == "api" and parts[1] == "session":
            session = save_player_session(self.read_json())
            self.send_json(session)
            return
        if len(parts) == 5 and parts[0] == "api" and parts[1] == "playlists" and parts[3] == "items" and parts[4] == "reorder":
            order = self.read_json().get("order", [])
            playlist = reorder_items(parts[2], order)
            if playlist is None:
                self.send_json({"error": "Invalid reorder"}, 400)
                return
            self.send_json(playlist)
            return
        if len(parts) == 3 and parts[0] == "api" and parts[1] == "playlists":
            playlist = update_playlist(parts[2], self.read_json())
            if playlist is None:
                self.send_json({"error": "Not found"}, 404)
                return
            self.send_json(playlist)
            return
        self.send_error(404)

    def do_DELETE(self) -> None:
        parsed = urlparse(self.path)
        parts = parsed.path.strip("/").split("/")
        if len(parts) == 3 and parts[:2] == ['api', 'accounts']:
            if not self.account_app_request_allowed():
                self.send_json({'error': 'Account connection request denied'}, 403)
                return
            try:
                account_connections.disconnect(parts[2])
                self.send_json({'ok': True})
            except ValueError as exc:
                self.send_json({'error': str(exc)}, 400)
            return
        if len(parts) == 3 and parts[0] == "api" and parts[1] == "playlists":
            if delete_playlist(parts[2]):
                self.send_json({"ok": True})
            else:
                self.send_json({"error": "Not found"}, 404)
            return
        if len(parts) == 5 and parts[3] == "items":
            if remove_item(parts[2], parts[4]):
                self.send_json({"ok": True})
            else:
                self.send_json({"error": "Not found"}, 404)
            return
        self.send_error(404)

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return {}

    def send_json(self, data: object, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def serve_item(self, playlist_id: str, item_id: str, quality: str = "original") -> None:
        playlist = load_playlist(playlist_id)
        if playlist is None:
            self.send_error(404)
            return
        item = next((i for i in playlist["items"] if i["id"] == item_id), None)
        if item is None:
            self.send_error(404)
            return
        media_path = resolve_item_path(playlist_id, item)
        if media_path is None:
            self.send_error(404, "Media file missing")
            return

        media_path = resolve_media_path(media_path, quality)

        mime, _ = mimetypes.guess_type(media_path.name)
        mime = mime or "application/octet-stream"
        size = media_path.stat().st_size
        range_header = self.headers.get("Range")

        if range_header:
            match = re.match(r"bytes=(\d+)-(\d*)", range_header)
            if match:
                start = int(match.group(1))
                end = int(match.group(2)) if match.group(2) else size - 1
                end = min(end, size - 1)
                with media_path.open("rb") as fh:
                    fh.seek(start)
                    chunk = fh.read(end - start + 1)
                self.send_response(206)
                self.send_header("Content-Type", mime)
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
                self.send_header("Content-Length", str(len(chunk)))
                self.end_headers()
                self.wfile.write(chunk)
                return

        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(size))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        with media_path.open("rb") as fh:
            shutil.copyfileobj(fh, self.wfile)


def playlist_path(playlist_id: str) -> Path:
    return PLAYLISTS_DIR / f"{playlist_id}.json"


def enrich_playlist(data: dict, playlist_id: str) -> dict:
    enriched = json.loads(json.dumps(data))
    for item in enriched.get("items", []):
        file_path = resolve_item_path(playlist_id, item)
        ref = item.get("file") or item.get("path", "")
        item["ext"] = Path(ref).suffix.lower().lstrip(".")
        item["kind"] = media_kind(file_path) if file_path else "audio"
        item["missing"] = file_path is None
        if file_path and item["kind"] == "video":
            height = probe_video_height(file_path)
            item["videoHeight"] = height
            item["qualities"] = build_quality_options(height)
        else:
            item["videoHeight"] = None
            item["qualities"] = []
    return enriched


def load_playlist(playlist_id: str) -> dict | None:
    path = playlist_path(playlist_id)
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    return enrich_playlist(data, playlist_id)


def save_playlist(data: dict) -> None:
    PLAYLISTS_DIR.mkdir(parents=True, exist_ok=True)
    playlist_path(data["id"]).write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def list_playlists() -> list[dict]:
    PLAYLISTS_DIR.mkdir(parents=True, exist_ok=True)
    playlists: list[dict] = []
    for path in sorted(PLAYLISTS_DIR.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        playlists.append(
            {
                "id": data["id"],
                "name": data.get("name", data["id"]),
                "trackCount": len(data.get("items", [])),
            }
        )
    return playlists


def unique_playlist_id(name: str) -> str:
    base = slugify(name)
    candidate = base
    index = 2
    while playlist_path(candidate).exists():
        candidate = f"{base}-{index}"
        index += 1
    return candidate


def create_playlist(name: str) -> dict:
    playlist_id = unique_playlist_id(name)
    data = {"id": playlist_id, "name": name.strip() or "New playlist", "items": []}
    save_playlist(data)
    (PLAYLISTS_DIR / playlist_id / "files").mkdir(parents=True, exist_ok=True)
    return data


def update_playlist(playlist_id: str, payload: dict) -> dict | None:
    data = load_playlist(playlist_id)
    if data is None:
        return None
    if "name" in payload and str(payload["name"]).strip():
        data["name"] = str(payload["name"]).strip()
    save_playlist(data)
    return load_playlist(playlist_id)


def delete_playlist(playlist_id: str) -> bool:
    path = playlist_path(playlist_id)
    if not path.exists():
        return False
    folder = PLAYLISTS_DIR / playlist_id
    path.unlink()
    if folder.exists():
        shutil.rmtree(folder, ignore_errors=True)
    return True


def add_path_item(playlist_id: str, file_path: str, title: str) -> dict | None:
    data = load_playlist(playlist_id)
    if data is None:
        return None
    path = Path(file_path.strip()).expanduser()
    if not path.is_file() or path.suffix.lower() not in MEDIA_EXTENSIONS:
        return None
    item = {
        "id": uuid.uuid4().hex[:10],
        "title": title.strip() or path.stem,
        "source": "path",
        "path": str(path.resolve()),
    }
    data["items"].append(item)
    save_playlist(data)
    return item


def parse_multipart(rfile, content_type: str, content_length: int) -> dict[str, bytes | str]:
    boundary = content_type.split("boundary=")[-1].encode()
    body = rfile.read(content_length)
    parts: dict[str, bytes | str] = {}
    for chunk in body.split(b"--" + boundary):
        if b"Content-Disposition" not in chunk:
            continue
        header, _, data = chunk.partition(b"\r\n\r\n")
        header_text = header.decode("utf-8", errors="replace")
        name_match = re.search(r'name="([^"]+)"', header_text)
        filename_match = re.search(r'filename="([^"]*)"', header_text)
        if not name_match:
            continue
        name = name_match.group(1)
        value = data.rstrip(b"\r\n--")
        if filename_match and filename_match.group(1):
            parts[name] = value
            parts[f"{name}__filename"] = filename_match.group(1)
        else:
            parts[name] = value.decode("utf-8", errors="replace").strip()
    return parts


def add_uploaded_item(playlist_id: str, rfile, headers, content_type: str) -> dict | None:
    data = load_playlist(playlist_id)
    if data is None:
        return None

    length = int(headers.get("Content-Length", 0))
    form = parse_multipart(rfile, content_type, length)
    upload = form.get("file")
    if not isinstance(upload, (bytes, bytearray)) or not upload:
        return None

    filename = str(form.get("file__filename", "track.bin"))
    title = str(form.get("title", "") or Path(filename).stem)
    suffix = Path(filename).suffix.lower()
    if suffix not in MEDIA_EXTENSIONS:
        return None

    files_dir = PLAYLISTS_DIR / playlist_id / "files"
    files_dir.mkdir(parents=True, exist_ok=True)
    safe_name = f"{uuid.uuid4().hex[:8]}{suffix}"
    dest = files_dir / safe_name
    dest.write_bytes(upload)

    item = {
        "id": uuid.uuid4().hex[:10],
        "title": title.strip() or dest.stem,
        "source": "upload",
        "file": f"files/{safe_name}",
    }
    data["items"].append(item)
    save_playlist(data)
    return item


def item_upload_path(playlist_id: str, item: dict) -> Path | None:
    if item.get("source") != "upload":
        return None
    rel = str(item.get("file", "")).strip()
    if not rel:
        return None
    path = (PLAYLISTS_DIR / playlist_id / rel).resolve()
    files_root = (PLAYLISTS_DIR / playlist_id / "files").resolve()
    if files_root not in path.parents and path != files_root:
        return None
    return path if path.is_file() else None


def delete_upload_file(playlist_id: str, item: dict) -> None:
    path = item_upload_path(playlist_id, item)
    if path is None:
        return
    stem = path.stem
    path.unlink(missing_ok=True)
    cache_dir = path.parent / ".transcode_cache"
    if cache_dir.is_dir():
        for cached in cache_dir.glob(f"{stem}_*p.mp4"):
            cached.unlink(missing_ok=True)


def cleanup_orphan_uploads(playlist_id: str, data: dict) -> None:
    files_dir = PLAYLISTS_DIR / playlist_id / "files"
    if not files_dir.is_dir():
        return
    referenced = {
        Path(str(item.get("file", ""))).name
        for item in data.get("items", [])
        if item.get("source") == "upload" and item.get("file")
    }
    for path in files_dir.iterdir():
        if path.is_file() and path.name not in referenced:
            delete_upload_file(playlist_id, {"source": "upload", "file": f"files/{path.name}"})


def remove_item(playlist_id: str, item_id: str) -> bool:
    data = load_playlist(playlist_id)
    if data is None:
        return False
    removed = next((item for item in data["items"] if item["id"] == item_id), None)
    if removed is None:
        return False
    data["items"] = [item for item in data["items"] if item["id"] != item_id]
    save_playlist(data)
    delete_upload_file(playlist_id, removed)
    cleanup_orphan_uploads(playlist_id, data)
    return True


def reorder_items(playlist_id: str, order: list[str]) -> dict | None:
    data = load_playlist(playlist_id)
    if data is None or not isinstance(order, list):
        return None
    by_id = {item["id"]: item for item in data.get("items", [])}
    if len(order) != len(by_id) or set(order) != set(by_id):
        return None
    data["items"] = [by_id[item_id] for item_id in order]
    save_playlist(data)
    return load_playlist(playlist_id)


def cleanup_all_playlist_files() -> None:
    for path in sorted(PLAYLISTS_DIR.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        playlist_id = data.get("id", path.stem)
        cleanup_orphan_uploads(playlist_id, data)


def prepare_playlists() -> None:
    PLAYLISTS_DIR.mkdir(parents=True, exist_ok=True)
    cleanup_all_playlist_files()


class PlaylistHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True


def host_label(host: str) -> str:
    return "127.0.0.1" if host in ("0.0.0.0", "::") else host


def build_app_url(host: str, port: int) -> str:
    return f"http://{host_label(host)}:{port}/"


def is_server_listening(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.3)
        return sock.connect_ex((host_label(host), port)) == 0


def wait_for_server(url: str, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=0.5) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError, OSError):
            time.sleep(0.05)
    raise RuntimeError(f"Server did not start: {url}")


def wait_until_port_closed(host: str, port: int, timeout: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not is_server_listening(host, port):
            return True
        time.sleep(0.05)
    return False


def create_server(host: str, port: int) -> PlaylistHTTPServer:
    prepare_playlists()
    return PlaylistHTTPServer((host, port), PlaylistHandler)


def create_server_on_port(host: str, preferred_port: int) -> tuple[PlaylistHTTPServer, int]:
    last_error: OSError | None = None
    for port in range(preferred_port, preferred_port + 20):
        if is_server_listening(host, port):
            continue
        try:
            return create_server(host, port), port
        except OSError as exc:
            last_error = exc
            continue
    raise RuntimeError(
        f"No free port found near {preferred_port}. Close other Trim Playlist windows and try again."
    ) from last_error


def stop_server(server: PlaylistHTTPServer, thread: threading.Thread | None = None) -> bool:
    host, port = server.server_address
    try:
        if thread and thread.is_alive():
            server.shutdown()
            thread.join(timeout=3.0)
    except Exception:
        pass
    try:
        server.server_close()
    except Exception:
        pass
    return wait_until_port_closed(host, port)


def main() -> None:
    parser = argparse.ArgumentParser(description="Start custom playlist player")
    parser.add_argument("--port", "-p", type=int, default=8765)
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Bind address (use 0.0.0.0 for LAN/team access)",
    )
    parser.add_argument("--no-open", action="store_true")
    parser.add_argument(
        "--app",
        action="store_true",
        help="Open in the desktop app window instead of the browser",
    )
    args = parser.parse_args()

    try:
        server, port = create_server_on_port(args.host, args.port)
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc

    url = build_app_url(args.host, port)

    print(f"Playlist server: {url}")
    if port != args.port:
        print(f"Port {args.port} is in use — switched to {port}")
    if args.host in ("0.0.0.0", "::"):
        print(f"LAN bind: http://0.0.0.0:{port}/ (use your PC IP from other devices)")
    print(f"Playlists saved: {PLAYLISTS_DIR}")
    print("Press Ctrl+C to stop")

    if args.app and not args.no_open:
        from trim_playlist_app import run_desktop_window

        run_desktop_window(url, server, args.host, port)
        return

    if not args.no_open:
        webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        if stop_server(server):
            print(f"Port {port} released.")
        else:
            print(f"Warning: port {port} may still be in use.")


if __name__ == "__main__":
    main()
