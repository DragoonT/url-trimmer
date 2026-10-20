FROM python:3.12-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    binutils \
    gcc \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-3.0 \
    gir1.2-webkit2-4.1 \
    libcairo2-dev \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
CMD ["bash", "-lc", "pip install -r requirements.txt -r requirements-build.txt && python -m PyInstaller --clean --noconfirm --distpath dist/linux-pack --workpath build/linux-pack TrimPlaylist.spec"]
