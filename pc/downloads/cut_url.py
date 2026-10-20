from __future__ import annotations

import sys
from pathlib import Path
for _parent in Path(__file__).resolve().parents:
    if (_parent / "pc" / "app" / "app_paths.py").is_file():
        _root = str(_parent)
        if _root not in sys.path:
            sys.path.insert(0, _root)
        break

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass
from pathlib import Path

from pc.app.app_paths import app_dir

@dataclass
class Track:
    name: str
    start: str
    end: str


@dataclass
class DownloadStats:
    speed: str | None = None
    size: str | None = None


class Progress:
    def __init__(self) -> None:
        self.last_percent = -1.0
        self.last_message = ""

    def update(self, percent: float, message: str = "", force: bool = False) -> None:
        percent = max(0.0, min(100.0, float(percent)))
        if (
            not force
            and self.last_percent >= 0
            and abs(percent - self.last_percent) < 0.3
            and message == self.last_message
        ):
            return
        self.last_percent = percent
        self.last_message = message
        filled = int(30 * percent / 100)
        bar = "=" * filled + "-" * (30 - filled)
        sys.stdout.write(f"\r[{bar}] {percent:5.1f}% {message:<40}")
        sys.stdout.flush()

    def finish(self, message: str = "Done") -> None:
        self.update(100.0, message, force=True)
        sys.stdout.write("\n")
        sys.stdout.flush()
        self.last_percent = -1.0
        self.last_message = ""

PROGRESS = Progress()

def find_ffmpeg() -> str:
    system_ffmpeg = shutil.which("ffmpeg")
    if system_ffmpeg:
        return system_ffmpeg
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError as exc:
        raise SystemExit(
            "ffmpeg not found. Install ffmpeg or run: pip install imageio-ffmpeg"
        ) from exc

def parse_time(value: str) -> int:
    """Convert MM:SS or H:MM:SS to total seconds."""
    parts = value.strip().split(":")
    if len(parts) == 2:
        minutes, seconds = parts
        hours = 0
    elif len(parts) == 3:
        hours, minutes, seconds = parts
    else:
        raise ValueError(f"Invalid time format: {value!r} (use MM:SS or H:MM:SS)")

    return int(hours) * 3600 + int(minutes) * 60 + int(seconds)

def format_time(total_seconds: int) -> str:
    hours, remainder = divmod(total_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{seconds:02d}"
    return f"{minutes:02d}:{seconds:02d}"

def sanitize_filename(name: str) -> str:
    cleaned = re.sub(r'[<>:"/\\|?*]', "-", name).strip()
    return cleaned or "track"


def output_filename(name: str, output_format: str, index: int | None = None, total: int = 1) -> str:
    safe_name = sanitize_filename(name)
    if total > 1 and index is not None:
        return f"{index:02d} - {safe_name}.{output_format}"
    return f"{safe_name}.{output_format}"


def pick_full_output_name(tracks: list[Track], output_format: str) -> str:
    if tracks:
        return output_filename(tracks[0].name, output_format)
    return f"full.{output_format}"


APP_DIR = app_dir()
COOKIES_DIR = APP_DIR / "cookies"


def resolve_app_path(path: Path) -> Path:
    return path if path.is_absolute() else (APP_DIR / path).resolve()


def resolve_cookies_path(cookies: str | None, platform: str) -> Path | None:
    """Resolve cookies file inside the cookies/ folder."""
    if cookies:
        path = Path(cookies)
        if path.is_absolute():
            return path
        if path.parent != Path("."):
            return path
        return COOKIES_DIR / path.name

    if platform == "facebook":
        default = COOKIES_DIR / "cookies.txt"
        if default.exists():
            return default

    return None


def detect_platform(url: str) -> str:
    if re.search(r"(youtube\.com|youtu\.be)", url, re.I):
        return "youtube"
    if re.search(r"(facebook\.com|fb\.watch|fb\.com)", url, re.I):
        return "facebook"
    return "other"


def clean_url(url: str, platform: str) -> str:
    if platform == "youtube":
        return re.sub(r"[?&]t=\d+s?", "", url).rstrip("?&")
    return url.split("#")[0].rstrip("?&")


VIDEO_QUALITIES: dict[str, tuple[str, int | None]] = {
    "best": ("Best available", None),
    "1080": ("1080p", 1080),
    "720": ("720p", 720),
    "480": ("480p", 480),
    "360": ("360p", 360),
}

AUDIO_QUALITIES: dict[str, tuple[str, int | None]] = {
    "best": ("Best audio", None),
    "320": ("320 kbps", 320),
    "192": ("192 kbps", 192),
    "128": ("128 kbps", 128),
}


def quality_label(output_format: str, quality: str) -> str:
    presets = VIDEO_QUALITIES if output_format == "mp4" else AUDIO_QUALITIES
    return presets.get(quality, presets["best"])[0]


def probe_video_height(path: Path) -> int | None:
    ffmpeg = find_ffmpeg()
    try:
        result = subprocess.run(
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


def build_ytdlp_format(output_format: str, quality: str) -> str:
    if output_format == "mp3":
        return "bestaudio/best"

    _, max_height = VIDEO_QUALITIES.get(quality, VIDEO_QUALITIES["best"])
    if max_height is None:
        return "bv*+ba/bv+ba/b"
    return (
        f"bv*[height<={max_height}]+ba/"
        f"b[height<={max_height}]/"
        f"bv*+ba/b"
    )


def ytdlp_format_sort(output_format: str, quality: str) -> str | None:
    if output_format != "mp4":
        return None
    _, max_height = VIDEO_QUALITIES.get(quality, VIDEO_QUALITIES["best"])
    if max_height is None:
        return None
    return f"res:{max_height},codec:h264,codec:vp9,codec:av01"


def build_ytdlp_command(
    url: str,
    output_dir: Path,
    ffmpeg: str,
    output_format: str,
    quality: str,
    filename: str,
    cookies: str | None,
    platform: str,
    extractor_args: list[str] | None = None,
) -> list[str]:
    template = str(output_dir / f"{filename}.%(ext)s")
    video_url = clean_url(url, platform)
    cmd = [
        sys.executable,
        "-m",
        "yt_dlp",
        "--no-update",
        "--newline",
        "--ffmpeg-location",
        ffmpeg,
        "-o",
        template,
    ]

    if extractor_args:
        cmd.extend(extractor_args)

    if cookies:
        cookies_path = resolve_cookies_path(cookies, platform)
        if cookies_path is None or not cookies_path.exists():
            raise SystemExit(
                f"Cookies file not found: {cookies_path or cookies}\n"
                f"Put your cookies file in: {COOKIES_DIR}"
            )
        cmd.extend(["--cookies", str(cookies_path)])
    elif platform == "facebook":
        default_cookies = resolve_cookies_path(None, platform)
        if default_cookies:
            cmd.extend(["--cookies", str(default_cookies)])

    format_sort = ytdlp_format_sort(output_format, quality)
    if format_sort:
        cmd.extend(["-S", format_sort])

    if output_format == "mp3":
        cmd.extend(["-f", build_ytdlp_format(output_format, quality)])
    else:
        cmd.extend(
            [
                "-f",
                build_ytdlp_format(output_format, quality),
                "--merge-output-format",
                "mp4",
            ]
        )

    cmd.append(video_url)
    return cmd


@dataclass
class DownloadStats:
    speed: str | None = None
    size: str | None = None
    avg_bps: float = 0.0


def parse_data_amount(text: str) -> int | None:
    match = re.match(r"([\d.]+)\s*(B|KiB|MiB|GiB|TiB)\b", text.strip(), re.I)
    if not match:
        return None
    value = float(match.group(1))
    unit = match.group(2).lower()
    multipliers = {
        "b": 1,
        "kib": 1024,
        "mib": 1024**2,
        "gib": 1024**3,
        "tib": 1024**4,
    }
    return int(value * multipliers[unit])


def parse_speed_bps(text: str) -> float | None:
    match = re.match(r"([\d.]+)\s*(B|KiB|MiB|GiB|TiB)/s", text.strip(), re.I)
    if not match:
        return None
    amount = parse_data_amount(f"{match.group(1)} {match.group(2)}")
    return float(amount) if amount is not None else None


def parse_duration_seconds(text: str) -> float | None:
    parts = text.strip().split(":")
    try:
        if len(parts) == 2:
            minutes, seconds = parts
            return int(minutes) * 60 + float(seconds)
        if len(parts) == 3:
            hours, minutes, seconds = parts
            return int(hours) * 3600 + int(minutes) * 60 + float(seconds)
    except ValueError:
        return None
    return None


def format_bytes(size: int) -> str:
    if size <= 0:
        return "0 B"
    value = float(size)
    units = ["B", "KB", "MB", "GB", "TB"]
    unit_idx = 0
    while value >= 1000 and unit_idx < len(units) - 1:
        value /= 1000
        unit_idx += 1
    if unit_idx == 0:
        return f"{value:.0f} {units[unit_idx]}"
    if value >= 100:
        return f"{value:.0f} {units[unit_idx]}"
    if value >= 10:
        return f"{value:.1f} {units[unit_idx]}"
    return f"{value:.2f} {units[unit_idx]}"


def format_speed(bps: float) -> str:
    if bps <= 0:
        return "0 B/s"
    value = float(bps)
    units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
    unit_idx = 0
    while value >= 1000 and unit_idx < len(units) - 1:
        value /= 1000
        unit_idx += 1
    if unit_idx == 0:
        return f"{value:.0f} {units[unit_idx]}"
    if value >= 100:
        return f"{value:.0f} {units[unit_idx]}"
    if value >= 10:
        return f"{value:.1f} {units[unit_idx]}"
    return f"{value:.2f} {units[unit_idx]}"


class SpeedTracker:
    def __init__(self) -> None:
        self.samples: list[float] = []
        self.start_time: float | None = None
        self.total_bytes: int | None = None

    def begin(self, percent: float, total_bytes: int | None) -> None:
        if self.start_time is None and percent > 0:
            self.start_time = time.time()
        if total_bytes:
            self.total_bytes = total_bytes

    def add_sample(self, bps: float) -> float:
        # Ignore bogus burst values from fragmented downloads.
        if bps <= 0 or bps > 2 * 1024**3:
            return self.smoothed()
        self.samples.append(bps)
        if len(self.samples) > 20:
            self.samples.pop(0)
        return self.smoothed()

    def smoothed(self) -> float:
        if not self.samples:
            return 0.0
        return sum(self.samples) / len(self.samples)

    def elapsed_average(self, percent: float) -> float | None:
        if self.start_time is None or not self.total_bytes or percent <= 0:
            return None
        elapsed = time.time() - self.start_time
        if elapsed < 1.0:
            return None
        downloaded = self.total_bytes * (percent / 100.0)
        return downloaded / elapsed

    def display_bps(self, percent: float, instant_bps: float | None) -> float:
        elapsed_avg = self.elapsed_average(percent)
        smoothed = self.add_sample(instant_bps) if instant_bps else self.smoothed()
        if elapsed_avg and percent >= 8:
            # Blend elapsed average (stable) with recent samples (responsive).
            return elapsed_avg * 0.7 + smoothed * 0.3
        return smoothed or instant_bps or 0.0

    def finalize(self, total_bytes: int | None, elapsed_seconds: float | None) -> float:
        if total_bytes and elapsed_seconds and elapsed_seconds > 0:
            return total_bytes / elapsed_seconds
        return self.smoothed()


def parse_ytdlp_download_line(
    line: str,
) -> tuple[float | None, float | None, int | None, float | None]:
    if "[download]" not in line:
        return None, None, None, None
    pct_match = re.search(r"([\d.]+)%", line)
    speed_match = re.search(r"at\s+([\d.]+\s*(?:MiB|KiB|GiB|TiB|B)/s)", line, re.I)
    size_match = re.search(r"of\s+~?\s*([\d.]+\s*(?:MiB|KiB|GiB|TiB|B))", line, re.I)
    duration_match = re.search(r"\bin\s+(\d+:\d+(?::\d+)?)", line)

    percent = float(pct_match.group(1)) if pct_match else None
    speed_bps = parse_speed_bps(speed_match.group(1)) if speed_match else None
    total_bytes = parse_data_amount(size_match.group(1)) if size_match else None
    elapsed = parse_duration_seconds(duration_match.group(1)) if duration_match else None
    return percent, speed_bps, total_bytes, elapsed


def run_ytdlp(cmd: list[str], status_message: str) -> tuple[int, DownloadStats]:
    stats = DownloadStats()
    tracker = SpeedTracker()
    last_ui_at = 0.0
    PROGRESS.update(0, status_message)
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert process.stdout is not None
    for line in process.stdout:
        percent, speed_bps, total_bytes, elapsed = parse_ytdlp_download_line(line)
        if percent is None:
            continue

        tracker.begin(percent, total_bytes)
        if total_bytes:
            stats.size = format_bytes(total_bytes)

        if percent >= 99.9 and total_bytes and elapsed:
            stats.avg_bps = tracker.finalize(total_bytes, elapsed)
        else:
            display_bps = tracker.display_bps(percent, speed_bps)
            if display_bps > 0:
                stats.avg_bps = display_bps

        now = time.time()
        if stats.avg_bps > 0 and (now - last_ui_at >= 0.25 or percent >= 99):
            stats.speed = format_speed(stats.avg_bps)
            msg = f"Downloading... {stats.speed}"
            PROGRESS.update(percent, msg, force=True)
            last_ui_at = now
        else:
            PROGRESS.update(percent, "Downloading...", force=False)

    return process.wait(), stats


def cache_meets_quality(path: Path, quality: str) -> bool:
    if quality == "best":
        return True
    _, wanted = VIDEO_QUALITIES.get(quality, VIDEO_QUALITIES["best"])
    if wanted is None:
        return True
    actual = probe_video_height(path)
    if actual is None:
        return True
    return actual >= int(wanted * 0.85)


def cache_suffix(output_format: str, quality: str) -> str:
    return f"{output_format}_{quality}"


def select_quality(config_quality: str = "", cli_quality: str | None = None, output_format: str = "mp4") -> str:
    presets = VIDEO_QUALITIES if output_format == "mp4" else AUDIO_QUALITIES
    if cli_quality and cli_quality in presets:
        return cli_quality
    if config_quality in presets:
        return config_quality

    options = list(presets.items())
    print(f"\n=== Select download quality ({output_format.upper()}) ===")
    for index, (key, (label, _)) in enumerate(options, start=1):
        print(f"  {index}. {label}")
    while True:
        choice = input(f"Select [1-{len(options)}]: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(options):
            return options[int(choice) - 1][0]
        print(f"Invalid choice. Enter 1-{len(options)}.")


def load_config(path: Path) -> tuple[str, str, str, str, float, bool, str | None, list[Track]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    url = data["url"]
    output_format = data.get("format", "mp3").lower()
    mode = data.get("mode", "").lower()
    quality = str(data.get("quality", "best")).lower()
    volume = float(data.get("volume", 2.0))
    normalize = bool(data.get("normalize", False))
    cookies = data.get("cookies")

    tracks: list[Track] = []
    for index, item in enumerate(data.get("tracks", [])):
        if "start" not in item or "end" not in item:
            raise SystemExit(
                f"Track {index + 1}: both 'start' and 'end' are required. Nothing is auto-set."
            )
        tracks.append(
            Track(
                name=item.get("name", f"Track {index + 1}"),
                start=item["start"],
                end=item["end"],
            )
        )

    return url, output_format, mode, quality, volume, normalize, cookies, tracks


def select_mode(config_mode: str = "", cli_mode: str | None = None) -> str:
    if cli_mode in ("full", "trim"):
        return cli_mode
    if config_mode in ("full", "trim"):
        return config_mode

    print("\n=== Select mode ===")
    print("  1. Download full (no trim)")
    print("  2. Download and trim tracks")
    while True:
        choice = input("Select [1/2]: ").strip()
        if choice == "1":
            return "full"
        if choice == "2":
            return "trim"
        print("Invalid choice. Enter 1 or 2.")

def build_audio_filter(volume: float, normalize: bool) -> str | None:
    if normalize:
        return "loudnorm=I=-14:TP=-1:LRA=11"
    if volume != 1.0:
        return f"volume={volume},alimiter=limit=0.95:level=false"
    return None


def append_mp4_encode_args(cmd: list[str], output_path: Path) -> None:
    """H.264 + AAC MP4 for mobile editors (CapCut, etc.)."""
    cmd.extend(
        [
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-profile:v",
            "high",
            "-level",
            "4.0",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-movflags",
            "+faststart",
            str(output_path),
        ]
    )


def append_output_args(
    cmd: list[str],
    output_format: str,
    output_path: Path,
    audio_filter: str | None,
    quality: str = "best",
) -> None:
    if output_format == "mp3":
        if audio_filter:
            cmd.extend(["-af", audio_filter])
        cmd.append("-vn")
        cmd.append("-acodec")
        cmd.append("libmp3lame")
        if quality in ("320", "192", "128"):
            cmd.extend(["-b:a", f"{quality}k"])
        else:
            cmd.extend(["-q:a", "2"])
        cmd.append(str(output_path))
        return

    if audio_filter:
        cmd.extend(["-af", audio_filter])
    append_mp4_encode_args(cmd, output_path)

def download_source(
    url: str,
    output_dir: Path,
    ffmpeg: str,
    output_format: str,
    cookies: str | None = None,
    filename: str = "source",
    reuse_existing: bool = True,
    quality: str = "best",
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)

    if reuse_existing:
        existing = sorted(output_dir.glob(f"{filename}.*"))
        if existing and cache_meets_quality(existing[0], quality):
            actual = probe_video_height(existing[0])
            label = f"{actual}p" if actual else "cached"
            PROGRESS.update(100, f"Source already downloaded ({label})")
            PROGRESS.finish()
            return existing[0]
        if existing:
            for old in existing:
                old.unlink(missing_ok=True)

    platform = detect_platform(url)
    platform_label = {"youtube": "YouTube", "facebook": "Facebook"}.get(platform, "video")
    quality_text = quality_label(output_format, quality)

    def try_download(extractor_args: list[str] | None, status_message: str) -> tuple[Path | None, DownloadStats]:
        cmd = build_ytdlp_command(
            url,
            output_dir,
            ffmpeg,
            output_format,
            quality,
            filename,
            cookies,
            platform,
            extractor_args,
        )
        return_code, stats = run_ytdlp(cmd, status_message)
        if return_code != 0:
            return None, stats
        matches = sorted(output_dir.glob(f"{filename}.*"))
        if not matches:
            return None, stats
        return matches[0], stats

    downloaded, stats = try_download(None, f"Starting {platform_label} download ({quality_text})...")
    if downloaded is None and platform == "youtube":
        sys.stdout.write("\n")
        downloaded, stats = try_download(
            ["--extractor-args", "youtube:player_client=android,web"],
            f"Retrying {platform_label} with fallback client...",
        )
        if downloaded is not None and quality not in ("best", ""):
            sys.stdout.write("\n")
            print("Note: Fallback client often limits YouTube to 360p. Add youtube cookies for HD.")

    if downloaded is None:
        sys.stdout.write("\n")
        if platform == "facebook":
            raise SystemExit(
                "Facebook download failed. Try:\n"
                "  1. pip install -U yt-dlp\n"
                "  2. Add cookies/cookies.txt (see README)\n"
                "  3. Use a public video URL"
            )
        raise SystemExit("Download failed. Try: pip install -U yt-dlp")

    actual_height = probe_video_height(downloaded)
    finish_parts = ["Download complete"]
    if actual_height:
        finish_parts.append(f"{actual_height}p")
    if stats.size:
        finish_parts.append(stats.size)
    if stats.avg_bps > 0:
        finish_parts.append(format_speed(stats.avg_bps))
    elif stats.speed:
        finish_parts.append(stats.speed)
    PROGRESS.finish(" · ".join(finish_parts))

    _, wanted_height = VIDEO_QUALITIES.get(quality, VIDEO_QUALITIES["best"])
    if wanted_height and actual_height and actual_height < int(wanted_height * 0.85):
        sys.stdout.write("\n")
        print(
            f"Warning: Downloaded {actual_height}p but you requested {wanted_height}p.\n"
            "  Add cookies/youtube_cookie.txt in cookies/ folder, then set in config:\n"
            '  "cookies": "youtube_cookie.txt"'
        )
    return downloaded


def export_output(
    source: Path,
    output_path: Path,
    ffmpeg: str,
    output_format: str,
    volume: float,
    normalize: bool,
    quality: str = "best",
) -> None:
    cmd = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(source),
    ]

    audio_filter = build_audio_filter(volume, normalize)
    append_output_args(cmd, output_format, output_path, audio_filter, quality)
    subprocess.run(cmd, check=True)

def parse_ffmpeg_progress_value(line: str) -> int | None:
    if "=" not in line:
        return None
    key, value = line.split("=", 1)
    value = value.strip()
    if value in ("N/A", ""):
        return None
    if key in ("out_time_ms", "out_time_us"):
        return int(value)
    if key == "out_time":
        parts = value.split(":")
        if len(parts) == 3:
            hours, minutes, seconds = parts
            return int(
                (int(hours) * 3600 + int(minutes) * 60 + float(seconds)) * 1_000_000
            )
    return None

def read_ffmpeg_progress_us(path: Path) -> int | None:
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None
    latest: int | None = None
    for line in lines:
        value = parse_ffmpeg_progress_value(line)
        if value is not None:
            latest = value
    return latest


def cut_segment(
    source: Path,
    track: Track,
    output_path: Path,
    ffmpeg: str,
    output_format: str,
    track_index: int,
    track_total: int,
    volume: float,
    normalize: bool,
    quality: str = "best",
    completed_seconds: float = 0.0,
    total_seconds: float = 0.0,
) -> None:
    start_seconds = parse_time(track.start)
    end_seconds = parse_time(track.end)
    duration = end_seconds - start_seconds
    if duration <= 0:
        raise ValueError(
            f"Track {track.name!r}: end ({track.end}) must be after start ({track.start})"
        )

    duration_us = duration * 1_000_000
    progress_path = Path(tempfile.gettempdir()) / f"ffmpeg_progress_{track_index}_{int(time.time() * 1000)}.txt"

    cmd = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-stats_period",
        "0.2",
        "-ss",
        str(start_seconds),
        "-i",
        str(source),
        "-t",
        str(duration),
        "-progress",
        str(progress_path),
    ]

    audio_filter = build_audio_filter(volume, normalize)
    append_output_args(cmd, output_format, output_path, audio_filter, quality)

    process = subprocess.Popen(cmd, stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
    stop_polling = threading.Event()

    def poll_progress() -> None:
        while not stop_polling.is_set():
            out_time_us = read_ffmpeg_progress_us(progress_path)
            if out_time_us is not None and duration_us > 0:
                track_percent = min(100.0, out_time_us / duration_us * 100)
                if total_seconds > 0:
                    done_seconds = completed_seconds + (duration * track_percent / 100.0)
                    overall = done_seconds / total_seconds * 100.0
                else:
                    overall = ((track_index - 1) + track_percent / 100.0) / track_total * 100.0
                short_name = track.name if len(track.name) <= 22 else track.name[:19] + "..."
                PROGRESS.update(
                    overall,
                    f"Cut {track_index}/{track_total} · {track_percent:.1f}% · {short_name}",
                    force=True,
                )
            time.sleep(0.1)

    poller = threading.Thread(target=poll_progress, daemon=True)
    poller.start()

    return_code = process.wait()
    stop_polling.set()
    poller.join(timeout=1)
    progress_path.unlink(missing_ok=True)

    if return_code != 0:
        stderr = process.stderr.read() if process.stderr else ""
        raise subprocess.CalledProcessError(return_code, cmd, stderr=stderr)

    if total_seconds > 0:
        overall = (completed_seconds + duration) / total_seconds * 100.0
    else:
        overall = track_index / track_total * 100.0
    PROGRESS.update(overall, f"Cut {track_index}/{track_total} · 100.0%", force=True)

def run_full(
    url: str,
    output_dir: Path,
    output_format: str,
    volume: float,
    normalize: bool,
    cookies: str | None = None,
    tracks: list[Track] | None = None,
    quality: str = "best",
) -> None:
    tracks = tracks or []
    ffmpeg = find_ffmpeg()
    platform = detect_platform(url)
    platform_label = {"youtube": "YouTube", "facebook": "Facebook"}.get(platform, "Video")
    print(f"Using ffmpeg: {ffmpeg}")
    print(f"Source: {platform_label}")
    print(f"Format: {output_format}" + (" (H.264 + AAC, editor-friendly)" if output_format == "mp4" else ""))
    print(f"Quality: {quality_label(output_format, quality)}")
    print("Mode: download full (no trim)")
    if normalize:
        print("Volume: auto normalize (loudnorm)")
    elif volume != 1.0:
        print(f"Volume: {volume}x boost")
    else:
        print("Volume: original (no change)")

    final_name = pick_full_output_name(tracks, output_format)
    final_path = output_dir / final_name
    cache_name = f"_cache_full_{cache_suffix(output_format, quality)}"

    output_dir.mkdir(parents=True, exist_ok=True)
    downloaded = download_source(
        url,
        output_dir,
        ffmpeg,
        output_format,
        cookies,
        filename=cache_name,
        reuse_existing=True,
        quality=quality,
    )

    needs_export = (
        output_format == "mp4"
        or downloaded.suffix.lower() != f".{output_format}"
        or volume != 1.0
        or normalize
        or downloaded.name != final_name
    )

    if needs_export:
        PROGRESS.update(0, "Processing...")
        export_output(downloaded, final_path, ffmpeg, output_format, volume, normalize, quality)
        if downloaded != final_path and downloaded.exists():
            downloaded.unlink()
        PROGRESS.finish("Processing complete")
        result = final_path
    elif downloaded != final_path:
        downloaded.rename(final_path)
        result = final_path
    else:
        result = downloaded

    print(f"\nDone. File saved to: {result.resolve()}")


def run_trim(
    url: str,
    tracks: list[Track],
    output_dir: Path,
    output_format: str,
    keep_source: bool,
    volume: float,
    normalize: bool,
    cookies: str | None = None,
    quality: str = "best",
) -> None:
    ffmpeg = find_ffmpeg()
    platform = detect_platform(url)
    platform_label = {"youtube": "YouTube", "facebook": "Facebook"}.get(platform, "Video")
    print(f"Using ffmpeg: {ffmpeg}")
    print(f"Source: {platform_label}")
    print(f"Format: {output_format}" + (" (H.264 + AAC, editor-friendly)" if output_format == "mp4" else ""))
    print(f"Quality: {quality_label(output_format, quality)}")
    print("Mode: download and trim")
    if normalize:
        print("Volume: auto normalize (loudnorm)")
    elif volume != 1.0:
        print(f"Volume: {volume}x boost")
    else:
        print("Volume: original (no change)")

    print(f"\n{len(tracks)} track(s) — start and end set by you:\n")
    for index, track in enumerate(tracks, start=1):
        duration = parse_time(track.end) - parse_time(track.start)
        print(
            f"  {index:02d}. {track.name}  "
            f"{track.start} -> {track.end}  ({format_time(duration)})"
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    source = download_source(
        url,
        output_dir,
        ffmpeg,
        output_format,
        cookies,
        filename=f"source_{cache_suffix(output_format, quality)}",
        quality=quality,
    )

    track_total = len(tracks)
    track_durations = [parse_time(t.end) - parse_time(t.start) for t in tracks]
    total_seconds = sum(track_durations)
    completed_seconds = 0.0

    PROGRESS.update(0.0, f"Cut 0/{track_total} · 0.0%")
    for index, track in enumerate(tracks, start=1):
        filename = output_filename(track.name, output_format, index, track_total)
        output_path = output_dir / filename
        cut_segment(
            source,
            track,
            output_path,
            ffmpeg,
            output_format,
            index,
            track_total,
            volume,
            normalize,
            quality,
            completed_seconds,
            total_seconds,
        )
        completed_seconds += track_durations[index - 1]

    PROGRESS.finish("All tracks cut")

    if not keep_source:
        source.unlink(missing_ok=True)
        print("\nRemoved temporary source file.")

    print(f"\nDone. Files saved to: {output_dir.resolve()}")

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Download and trim videos from a URL (YouTube, Facebook, and more).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python pc/downloads/cut_url.py --config setlist.json
  python pc/downloads/cut_url.py --config setlist.json --mode full
  python pc/downloads/cut_url.py --config setlist.json --mode trim
  python pc/downloads/cut_url.py --url "https://youtube.com/watch?v=..." --mode full
  python pc/downloads/cut_url.py --config setlist.json --quality 720
  python pc/downloads/cut_url.py --url "https://facebook.com/watch/?v=..." --start 0:00 --end 0:52 --name "Song 1"

Use --mode full for full download, --mode trim to cut tracks.
Use --quality best|1080|720|480|360 for MP4, or best|320|192|128 for MP3.
Without --mode or --quality, interactive menus are shown.
        """,
    )
    parser.add_argument("--config", "-c", type=Path, help="JSON config file")
    parser.add_argument("--url", "-u", help="Video URL (YouTube, Facebook, etc.)")
    parser.add_argument(
        "--mode",
        "-m",
        choices=["full", "trim"],
        help="full = download entire video, trim = cut tracks from config",
    )
    parser.add_argument("--start", "-s", help="Start time: MM:SS or H:MM:SS")
    parser.add_argument("--end", "-e", help="End time: MM:SS or H:MM:SS")
    parser.add_argument("--name", "-n", default="Track", help="Track name")
    parser.add_argument(
        "--quality",
        "-q",
        choices=["best", "1080", "720", "480", "360", "320", "192", "128"],
        help="Download quality: MP4=1080/720/480/360/best, MP3=320/192/128/best",
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["mp3", "mp4"],
        default=None,
        help="Output format (default: from config, or mp3)",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=None,
        help="Output folder (default: output/ next to the app)",
    )
    parser.add_argument(
        "--volume",
        type=float,
        default=2.0,
        help="Volume multiplier (default: 2.0). Use 1.0 for original volume.",
    )
    parser.add_argument(
        "--normalize",
        action="store_true",
        help="Auto normalize loudness instead of fixed volume boost",
    )
    parser.add_argument(
        "--cookies",
        type=Path,
        help="Cookies filename in cookies/ folder (often needed for Facebook)",
    )
    parser.add_argument(
        "--keep-source",
        action="store_true",
        help="Keep the downloaded full video after cutting",
    )
    return parser

def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    volume = args.volume
    normalize = args.normalize
    cookies = str(args.cookies) if args.cookies else None
    config_mode = ""
    config_quality = ""
    tracks: list[Track] = []
    url = args.url
    output_format = args.format
    quality = args.quality
    output_dir = resolve_app_path(args.output) if args.output else (APP_DIR / "output")

    if args.config:
        config_path = resolve_app_path(args.config)
        url, config_format, config_mode, config_quality, config_volume, config_normalize, config_cookies, tracks = (
            load_config(config_path)
        )
        output_format = args.format if args.format is not None else config_format
        if args.volume == 2.0:
            volume = config_volume
        if not args.normalize:
            normalize = config_normalize
        if not args.cookies and config_cookies:
            cookies = config_cookies
        mode = select_mode(config_mode, args.mode)
        quality = select_quality(config_quality, args.quality, output_format)
    elif args.url and args.start and args.end:
        tracks = [Track(name=args.name, start=args.start, end=args.end)]
        output_format = args.format or "mp3"
        mode = select_mode("", args.mode or "trim")
        quality = select_quality("", args.quality, output_format)
    elif args.url and args.mode == "full":
        output_format = args.format or "mp3"
        mode = "full"
        quality = select_quality("", args.quality, output_format)
    else:
        parser.error(
            "Provide --config OR --url with --mode full OR --url + --start + --end"
        )

    if mode == "full":
        if not url:
            raise SystemExit("URL is required for full download")
        run_full(
            url=url,
            output_dir=output_dir,
            output_format=output_format,
            volume=volume,
            normalize=normalize,
            cookies=cookies,
            tracks=tracks,
            quality=quality,
        )
        return

    if not tracks:
        raise SystemExit("Trim mode requires tracks in config or --start/--end")

    run_trim(
        url=url,
        tracks=tracks,
        output_dir=output_dir,
        output_format=output_format,
        keep_source=args.keep_source,
        volume=volume,
        normalize=normalize,
        cookies=cookies,
        quality=quality,
    )

if __name__ == "__main__":
    main()
