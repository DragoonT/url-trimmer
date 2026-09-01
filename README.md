# URL Trimmer

Download and trim videos from any supported URL into MP3 or MP4 files. Paste a link, set start/end times, and export tracks with names from your setlist.

## Supported URLs

| Platform | Example URL |
|----------|-------------|
| YouTube | `https://www.youtube.com/watch?v=VIDEO_ID` |
| YouTube | `https://youtu.be/VIDEO_ID` |
| Facebook | `https://www.facebook.com/watch/?v=VIDEO_ID` |
| Facebook | `https://fb.watch/VIDEO_ID` |
| Facebook | `https://www.facebook.com/share/r/...` |
| Other | Any URL supported by [yt-dlp](https://github.com/yt-dlp/yt-dlp) |

The tool reads a video **URL** from your config and detects the platform automatically.

## Requirements

- Python 3.10+
- Internet connection

Dependencies: `yt-dlp`, `imageio-ffmpeg` (FFmpeg bundled — no separate install needed).

## Setup

```powershell
cd url-trimmer
pip install -r requirements.txt
```

## Quick start

1. Copy an example config:

```powershell
copy setlist.youtube.example.json setlist.json
```

2. Edit `setlist.json`:
   - Set your video **url**
   - Add each track with `name`, `start`, and `end`

3. Run:

```powershell
python cut_url.py --config setlist.json
```

Menu:

```
=== Select mode ===
  1. Download full (no trim)
  2. Download and trim tracks
Select [1/2]:

=== Select download quality (MP4) ===
  1. Best available
  2. 1080p
  3. 720p
  4. 480p
  5. 360p
Select [1-5]:
```

Or set quality in config / CLI to skip the quality menu:

```powershell
python cut_url.py --config setlist.json --quality 720
```

Output files go to `output/` and use the **name** from your setlist JSON.

## Modes

| Mode | Description |
|------|-------------|
| **full** | Download entire video/audio as one file (named from setlist) |
| **trim** | Download and cut into separate tracks using start/end times |

```powershell
python cut_url.py --config setlist.json --mode full
python cut_url.py --config setlist.json --mode trim
python cut_url.py --url "https://youtube.com/watch?v=..." --mode full
```

Or in config:

```json
"mode": "full"
```

## Config file

```json
{
  "url": "https://www.youtube.com/watch?v=YOUR_VIDEO_ID",
  "format": "mp4",
  "quality": "720",
  "volume": 2.0,
  "tracks": [
    {
      "name": "Artist - Song Title",
      "start": "0:00",
      "end": "3:30"
    }
  ]
}
```

For Facebook, add a cookies file name (see [Cookies](#cookies)):

```json
{
  "url": "https://www.facebook.com/watch/?v=YOUR_VIDEO_ID",
  "format": "mp4",
  "cookies": "cookies.txt",
  "tracks": [
    {
      "name": "Artist - Song Title",
      "start": "0:00",
      "end": "3:30"
    }
  ]
}
```

Examples: `setlist.youtube.example.json`, `setlist.facebook.example.json`

| Field | Description |
|-------|-------------|
| `url` | Video URL (YouTube, Facebook, etc.) |
| `mode` | `full` or `trim` (optional — shows menu if not set) |
| `format` | `mp3` or `mp4` (MP4 uses H.264 + AAC for mobile editors) |
| `quality` | Download quality — MP4: `best`, `1080`, `720`, `480`, `360` — MP3: `best`, `320`, `192`, `128` |
| `volume` | Volume multiplier (default `2.0`) |
| `normalize` | `true` = auto-normalize loudness |
| `cookies` | Cookie filename inside `cookies/` folder |
| `tracks` | List of songs to cut |
| `tracks[].name` | Output filename |
| `tracks[].start` | Start time (`MM:SS` or `H:MM:SS`) |
| `tracks[].end` | End time (`MM:SS` or `H:MM:SS`) |

**Naming:** Output files follow `name` from setlist — e.g. `"name": "Artist - Song Title"` → `Artist - Song Title.mp4`

## Cookies

Some URLs (especially Facebook) need login cookies in the `cookies/` folder:

```
cookies/
  facebook_cookie.txt
  youtube_cookie.txt
  cookies.txt
```

In config:

```json
"cookies": "cookies.txt"
```

Export with browser extension **"Get cookies.txt LOCALLY"**, save into `cookies/`, then reference the filename in config.

## Command line

```powershell
python cut_url.py --url "https://youtube.com/watch?v=YOUR_VIDEO_ID" --start 15:52 --end 19:20 --name "Artist - Song"
python cut_url.py --url "https://facebook.com/watch/?v=YOUR_VIDEO_ID" --mode full --format mp4 --cookies cookies.txt
```

### Options

| Option | Description |
|--------|-------------|
| `--config`, `-c` | JSON config file |
| `--url`, `-u` | Video URL |
| `--mode`, `-m` | `full` or `trim` |
| `--start`, `-s` | Start time |
| `--end`, `-e` | End time |
| `--name`, `-n` | Track name |
| `--format`, `-f` | `mp3` or `mp4` |
| `--quality`, `-q` | Download quality: MP4 `best`/`1080`/`720`/`480`/`360`, MP3 `best`/`320`/`192`/`128` |
| `--volume` | Volume multiplier (default `2.0`) |
| `--normalize` | Auto-normalize loudness |
| `--cookies` | Cookie file in `cookies/` folder |
| `--output`, `-o` | Output folder (default: `output`) |
| `--keep-source` | Keep downloaded source after cutting |

## Volume

Default **2x** boost with limiter (quieter exports are common):

```json
"volume": 2.0
```

Use `"volume": 1.0` for original level, or `"normalize": true` for auto-normalize.

## MP4 for video editors

MP4 files are re-encoded to **H.264 + AAC** (`yuv420p`) so they work in CapCut and other mobile editors. Older downloads (VP9/AV1) may show "Unsupported format" — re-run after deleting old files in `output/`.

## Progress

```
[==============----------------]  45% Downloading...
[==============================] 100% Download complete
[===============---------------]  50% Cutting 1/2...
[==============================] 100% All tracks cut
```

## Troubleshooting

**Download failed**

```powershell
pip install -U yt-dlp
```

**Facebook / private videos** — add cookies in `cookies/` folder.

**Wrong format (mp3 vs mp4)** — set `"format": "mp4"` in config; delete old files in `output/`.

**Re-cut** — delete output files and run again. Delete `output/_cache_*` to re-download.

## Trim Playlist (desktop app)

Create your own playlists with custom names and pick files yourself:

```powershell
python trim_playlist_app.py
```

Or double-click **`start-playlist.bat`**. Opens in its **own app window** (not a browser tab).

For browser mode with Python:

```powershell
python playlist_server.py
```

### How to use

1. Click **+ New** → create playlist name
2. **Add track**:
   - Pick file from your PC (mp3, mp4, etc.), or
   - Paste file path like `C:\Users\you\Music\song.mp3`
3. Click track to play
4. **MP4** = watch video, **MP3** = listen
5. **Repeat**: off → repeat playlist → repeat one track

Playlists saved in `playlists/` folder (not from `output/` auto-scan).

Playback position is saved in **`player-session.json`** (same folder as the app). Browser and `.exe` share it — close one, open the other, and it continues the same track and time.

## Run as .exe (no Python needed)

Build once (requires Python on your PC):

```powershell
cd url-trimmer
.\build-exe.bat
```

Then double-click:

- **`dist\TrimPlaylist\TrimPlaylist.exe`** — starts the server automatically and opens the app window
- **`dist\TrimPlaylist\Run Trim Playlist.bat`** — same shortcut
- **`trim-url.bat`** — download/trim URLs (recommended; uses Python, same as `cut_url.py`)

Optional: **`dist\UrlTrimmer\UrlTrimmer.exe`** — same trimmer without Python installed. **Windows Security may delete this file** (false positive). If it disappears, use **`trim-url.bat`** instead, or add an exclusion in Windows Security for `url-trimmer\dist\UrlTrimmer`.

No need to run `python playlist_server.py` first. The server runs **inside** the `.exe`. Close the app window to stop the server and free the port.

If port `8765` is already in use (browser or another `.exe` open), the next free port is picked automatically (8766, 8767, …).

**Data folders** (`playlists/`, `player-session.json`, `output/`, `cookies/`) live in the **`url-trimmer` project folder** — the same place the browser app uses. The `.exe` finds that folder automatically when it sits in `dist/TrimPlaylist/`.

You can copy the whole `dist/TrimPlaylist` or `dist/UrlTrimmer` folder to another PC — no Python install required. On another PC, data is stored next to the `.exe` unless you set `TRIM_PLAYLIST_DIR` to a custom folder.
