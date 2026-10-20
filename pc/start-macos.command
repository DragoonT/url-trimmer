#!/bin/sh
cd "$(dirname "$0")/.." || exit 1
if ! command -v python3 >/dev/null 2>&1; then
  echo "Install Python 3, then run this script again."
  exit 1
fi
if [ ! -d .venv ]; then
  python3 -m venv .venv || exit 1
fi
# shellcheck disable=SC1091
. .venv/bin/activate
python -m pip install -r requirements.txt || exit 1
exec python pc/app/trim_playlist_app.py
