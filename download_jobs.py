from pathlib import Path
import threading
import uuid
import tempfile
import subprocess
import re
from urllib.parse import urlparse
from app_paths import app_dir, run_hidden, hidden_subprocess_kwargs

jobs = {}
lock = threading.Lock()

def download_cookie_path(data):
    if data.get('auth_source', 'cookie') not in ('cookie', 'platform', 'none'):
        raise ValueError('Choose a valid authentication method')
    if data.get('auth_source', 'cookie') == 'none':
        return None
    if data.get('auth_source') == 'platform':
        import account_connections
        platform = data.get('platform')
        path = account_connections.cookie_path(platform)
        if not any(a['platform'] == platform and a['connected'] for a in account_connections.list_accounts()):
            raise ValueError('Connect the selected platform account first')
        return path
    cookie = str(data.get('cookies', '')).strip()
    if not cookie:
        return None
    if Path(cookie).name != cookie or '/' in cookie or '\\' in cookie or not cookie.lower().endswith('.txt') or cookie.lower() == 'readme.txt':
        raise ValueError('Choose a cookie filename from cookies/')
    path = app_dir() / 'cookies' / cookie
    if not path.is_file():
        raise ValueError('Cookies file not found in cookies/')
    return path


def preview_download(data):
    url = str(data.get('url', '')).strip()
    if urlparse(url).scheme not in ('http', 'https'):
        raise ValueError('Enter a valid video or playlist URL')
    cookie = download_cookie_path(data)
    job_id = uuid.uuid4().hex
    with lock:
        jobs[job_id] = {'status': 'running', 'message': 'Loading playlist items', 'percent': None, 'files': []}
    def worker():
        try:
            import yt_dlp
            options = {'quiet': True, 'extract_flat': 'in_playlist', 'skip_download': True,
                       'noplaylist': True, 'js_runtimes': {'deno': {}, 'node': {}}, 'socket_timeout': 30}
            if cookie:
                options['cookiefile'] = str(cookie)
            with yt_dlp.YoutubeDL(options) as downloader:
                info = downloader.extract_info(url, download=False)
            is_playlist = info.get('_type') in ('playlist', 'multi_video')
            items = []
            if is_playlist:
                for index, entry in enumerate(info.get('entries') or [], 1):
                    available = bool(entry and entry.get('url') and entry.get('title') not in ('[Private video]', '[Deleted video]'))
                    items.append({'index': index, 'title': (entry or {}).get('title') or 'Unavailable item',
                                  'available': available, 'duration': (entry or {}).get('duration')})
            with lock:
                jobs[job_id].update(status='complete', is_playlist=is_playlist, items=items,
                                    title=info.get('title') or 'Playlist', message='Choose items to download')
        except Exception as exc:
            with lock:
                jobs[job_id].update(status='error', message=str(exc))
    threading.Thread(target=worker, daemon=True).start()
    return job_id


def start_download(data):
    url = str(data.get('url', '')).strip()
    if urlparse(url).scheme not in ('http', 'https'):
        raise ValueError('Enter a valid video or playlist URL')
    mode = data.get('mode', 'full')
    fmt = data.get('format', 'mp4')
    quality = str(data.get('quality', 'best'))
    if mode not in ('full', 'trim') or fmt not in ('mp3', 'mp4'):
        raise ValueError('Invalid mode or format')
    if quality not in ('best', '1080', '720', '480', '360'):
        raise ValueError('Invalid quality')
    audio_quality = str(data.get('audio_quality', 'best'))
    if fmt == 'mp3' and audio_quality not in ('best', '320', '256', '192', '128', '96', '64'):
        raise ValueError('Invalid MP3 quality')
    import math
    volume = float(data.get('volume', 1))
    if not math.isfinite(volume) or not 0 <= volume <= 10:
        raise ValueError('Volume must be between 0 and 10')
    def seconds(value):
        parts = str(value).split(':')
        if not 1 <= len(parts) <= 3:
            raise ValueError('Use seconds, MM:SS or HH:MM:SS')
        result = 0.0
        for part in parts:
            result = result * 60 + float(part)
        return result
    selection = data.get('selected_items')
    if selection is not None:
        if not isinstance(selection, list) or not selection or len(selection) > 1000 or any(type(i) is not int or i < 1 for i in selection):
            raise ValueError('Choose at least one valid playlist item')
        selection = sorted(set(selection))
        if mode == 'trim' and len(selection) != 1:
            raise ValueError('Choose exactly one item for Trim mode')
    start = end = None
    if mode == 'trim':
        start, end = seconds(data.get('start', '')), seconds(data.get('end', ''))
        if start < 0 or end <= start:
            raise ValueError('End must be after start')
        if data.get('playlist'):
            raise ValueError('Trim supports one video; use full mode for a playlist')
    cookie_path = download_cookie_path(data)
    job_id = uuid.uuid4().hex
    jobs[job_id] = {'status': 'running', 'percent': 0, 'message': 'Getting video information', 'files': []}
    def update(**values):
        with lock:
            jobs[job_id].update(values)
    def item_position(info):
        current = len(jobs[job_id]['files']) + 1
        total = len(selection) if selection else ((info.get('playlist_count') or info.get('n_entries')) if data.get('playlist') else 1)
        return current, int(total) if total else None
    def report(stage, info, percent):
        current, total = item_position(info)
        update(stage=stage, item=current, total=total, percent=percent,
               message=f'{stage} {current}/{total or "?"} · {info.get("title", "")}')
    def worker():
        try:
            import yt_dlp
            import imageio_ffmpeg
            import re
            ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
            output = app_dir() / 'output'
            output.mkdir(exist_ok=True)
            def hook(d):
                total = d.get('total_bytes') or d.get('total_bytes_estimate') or 0
                pct = d.get('downloaded_bytes', 0) / total * 100 if total else 0
                report('Downloading', d.get('info_dict', {}), round(min(100, pct), 1))
            with tempfile.TemporaryDirectory(dir=output, prefix='.download-') as temporary:
                options = {'outtmpl': str(Path(temporary) / '%(id)s.%(ext)s'), 'noplaylist': not bool(data.get('playlist') or selection), 'progress_hooks': [hook], 'quiet': True, 'ffmpeg_location': ffmpeg, 'js_runtimes': {'deno': {}, 'node': {}}}
                # noplaylist alone does not limit a playlist-only URL.
                if selection:
                    options['playlist_items'] = ','.join(map(str, selection))
                elif not data.get('playlist'):
                    options['playlist_items'] = '1'
                cap = '' if quality == 'best' else '[height<=' + quality + ']'
                options['format'] = 'bestaudio/best' if fmt == 'mp3' else 'bestvideo' + cap + '+bestaudio/best' + cap
                if cookie_path:
                    options['cookiefile'] = str(cookie_path)
                class Export(yt_dlp.postprocessor.PostProcessor):
                    def run(self, info):
                        source = info.get('filepath') or info.get('_filename')
                        title = str(data.get('name', '')).strip() if mode == 'trim' else ''
                        title = title or info.get('title') or info['id']
                        title = re.sub(r'[<>:"/\\|?*\x00-\x1f]', '-', title).strip().rstrip('.')[:180] or info['id']
                        destination = output / (title + '.' + fmt)
                        counter = 2
                        while destination.exists():
                            destination = output / (title + ' (' + str(counter) + ').' + fmt)
                            counter += 1
                        report('Exporting', info, 0)
                        cmd = [ffmpeg, '-y', '-hide_banner', '-loglevel', 'error']
                        if start is not None:
                            cmd += ['-ss', str(start)]
                        cmd += ['-i', source]
                        if end is not None:
                            cmd += ['-t', str(end-start)]
                        if volume != 1:
                            cmd += ['-af', f'volume={volume},alimiter=limit=0.95:level=false']
                        if fmt == 'mp3':
                            cmd += ['-vn', '-c:a', 'libmp3lame']
                            cmd += ['-q:a', '0'] if audio_quality == 'best' else ['-b:a', audio_quality + 'k']
                        else:
                            cmd += ['-c:v', 'libx264', '-preset', 'fast', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-movflags', '+faststart']
                        duration = end - start if end is not None else info.get('duration')
                        if not duration:
                            probe = run_hidden([ffmpeg, '-hide_banner', '-i', source], capture_output=True, text=True, encoding='utf-8', errors='replace')
                            match = re.search(r'Duration: (\d+):(\d+):(\d+(?:\.\d+)?)', probe.stderr)
                            if match:
                                h, m, sec = map(float, match.groups())
                                duration = h * 3600 + m * 60 + sec
                        export_with_progress(cmd, destination, duration,
                                             lambda percent: report('Exporting', info, percent))
                        with lock:
                            jobs[job_id]['files'].append(destination.name)
                        return [], info
                with yt_dlp.YoutubeDL(options) as downloader:
                    downloader.add_post_processor(Export(downloader), when='after_move')
                    downloader.download([url])
            update(status='complete', percent=100, message='Saved to output/')
        except Exception as exc:
            update(status='error', message=str(exc))
    threading.Thread(target=worker, daemon=True).start()
    return job_id

def get_job(job_id):
    with lock:
        result = dict(jobs.get(job_id, {'status': 'error', 'message': 'Download not found'}))
        if 'files' in result:
            result['files'] = list(result['files'])
        return result


def export_with_progress(cmd, destination, duration, on_progress):
    """Stream FFmpeg progress; reserve 100% for a successful process exit."""
    on_progress(0 if duration else None)
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(
            cmd + ['-nostats', '-stats_period', '0.2', '-progress', 'pipe:1', str(destination)],
            stdout=subprocess.PIPE, stderr=errors, text=True, encoding='utf-8',
            errors='replace', **hidden_subprocess_kwargs())
        try:
            for line in process.stdout:
                key, _, value = line.strip().partition('=')
                if key == 'out_time_us' and duration:
                    try:
                        percent = max(0, min(99.9, int(value) / (float(duration) * 1_000_000) * 100))
                    except ValueError:
                        continue
                    on_progress(round(percent, 1))
            return_code = process.wait()
        finally:
            process.stdout.close()
            if process.poll() is None:
                process.kill()
                process.wait()
        if return_code:
            errors.seek(0)
            detail = errors.read().decode('utf-8', errors='replace').strip()
            raise RuntimeError(detail or f'FFmpeg export failed ({return_code})')
    on_progress(100)
