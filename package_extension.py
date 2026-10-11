"""Build the downloadable connector without including account data."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED


def package_extension(root=None):
    root = Path(root) if root else Path(__file__).resolve().parent
    destination = root / "player" / "trim-playlist-account-connector.zip"
    with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
        for name in ("manifest.json", "background.js", "bridge.js", "README.md", "icon128.png"):
            archive.write(root / "browser-extension" / name, name)
    return destination


if __name__ == "__main__":
    print(package_extension())
