"""Resolve temporary browser-playable streams without saving media files."""
import threading
import time
from urllib.parse import urlparse
from pc.downloads.download_jobs import download_cookie_path

_cache = {}
_lock = threading.Lock()


def build_online_items(payload, preview):
    if preview.get('status') != 'complete' or 'items' not in preview:
        raise ValueError('Load the URL before adding tracks')
    indexes = payload.get('indexes')
    if not isinstance(indexes, list) or not indexes or len(indexes) > 1000 or any(type(i) is not int or i < 1 for i in indexes):
        raise ValueError('Select at least one online track')
    mode = payload.get('playback', 'video')
    if mode not in ('video', 'audio'):
        raise ValueError('Choose Video or Audio only')
    by_index = {item['index']: item for item in preview['items']}
    selected = []
    for index in sorted(set(indexes)):
        item = by_index.get(index)
        if not item or not item.get('available') or urlparse(item.get('url', '')).scheme not in ('http', 'https'):
            raise ValueError('Selected track is unavailable; reload the URL')
        selected.append({'source': 'online', 'url': item['url'], 'title': item['title'],
                         'cookies': preview.get('cookies', ''), 'kind': mode,
                         'duration': item.get('duration'), 'ext': 'stream'})
    custom = str(payload.get('title', '')).strip()
    if custom and len(selected) == 1:
        selected[0]['title'] = custom
    return selected


def resolve_stream(item, quality='original'):
    cookie = download_cookie_path({'cookies': item.get('cookies', '')})
    mode = item.get('kind', 'video')
    quality = str(quality)
    if quality not in ('', 'original', 'best', '1080', '720', '480', '360'):
        quality = 'original'
    key = (item['url'], mode, quality, str(cookie), cookie.stat().st_mtime_ns if cookie else 0)
    with _lock:
        cached = _cache.get(key)
        if cached and cached['expires'] > time.time():
            return cached
        import yt_dlp
        if mode == 'audio':
            media_format = 'bestaudio[ext=m4a][protocol=https]/bestaudio[protocol=https]/bestaudio[protocol=http]'
        elif quality.isdigit():
            # Do not silently downgrade a requested quality. Browser playback
            # needs one stream containing both video and audio; many platforms
            # provide 1080p only as two separate adaptive streams.
            media_format = f'bestvideo[height={quality}][vcodec^=avc1][protocol=https]+bestaudio[acodec^=mp4a][protocol=https]/best[height={quality}][acodec!=none][vcodec!=none][protocol=https]'
        else:
            media_format = 'best[ext=mp4][vcodec^=avc1][protocol=https]/best[ext=mp4][protocol=https]/best[protocol=https]/best[protocol=http]'
        options = {'quiet': True, 'noplaylist': True, 'playlist_items': '1',
                   'skip_download': True, 'js_runtimes': {'deno': {}, 'node': {}}, 'socket_timeout': 20,
                   'format': media_format}
        if cookie:
            options['cookiefile'] = str(cookie)
        with yt_dlp.YoutubeDL(options) as downloader:
            info = downloader.extract_info(item['url'], download=False)
        requested = info.get('requested_formats') or []
        if len(requested) == 2:
            video, audio = requested
            cached = {'adaptive': True, 'video_url': video['url'], 'audio_url': audio['url'],
                      'headers': info.get('http_headers', {}), 'mime': 'video/mp4', 'expires': time.time() + 300}
            _cache[key] = cached
            return cached
        url = info.get('url', '')
        if urlparse(url).scheme not in ('http', 'https'):
            raise ValueError('No progressive stream is available for this video')
        ext = info.get('ext', '')
        mime = {'m4a': 'audio/mp4', 'mp4': 'video/mp4', 'webm': 'audio/webm' if mode == 'audio' else 'video/webm', 'mp3': 'audio/mpeg'}.get(ext, 'application/octet-stream')
        cached = {'url': url, 'headers': info.get('http_headers', {}), 'mime': mime,
                  'expires': time.time() + 300}
        _cache[key] = cached
        # Retain only current resolutions; never persist signed stream URLs.
        for old in list(_cache):
            if _cache[old]['expires'] <= time.time():
                del _cache[old]
        return cached
