"""Create a portable Trim Playlist source archive without executables or private data."""

from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = ROOT / "dist" / "portable" / "TrimPlaylist-portable-source.zip"
SKIP_PARTS = {".agents", ".git", ".gradle", "__pycache__", "build", "dist", "output", "playlists"}
SKIP_NAMES = {"setlist.json", "player-session.json", "local.properties"}
PRIVATE_SUFFIXES = {".pyc", ".pyo", ".tmp", ".log"}


def should_include(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    if any(part in SKIP_PARTS for part in relative.parts):
        return False
    if path.name in SKIP_NAMES or path.suffix.lower() in PRIVATE_SUFFIXES:
        return False
    if relative.parts and relative.parts[0] == "cookies" and path.name != "README.txt":
        return False
    return True


def build_archive(output: Path) -> int:
    output.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob("*")):
            if path.is_file() and should_include(path):
                archive.write(path, path.relative_to(ROOT).as_posix())
                count += 1
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    count = build_archive(args.output.resolve())
    print(f"Created {args.output.resolve()} with {count} files.")


if __name__ == "__main__":
    main()
