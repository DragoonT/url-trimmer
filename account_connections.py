"""Short-lived, platform-scoped pairing with the local browser extension."""
import http.cookiejar
import math
import secrets
import threading
import time
from pathlib import Path
from app_paths import app_dir

PLATFORMS = {
    'youtube': ('YouTube', 'https://www.youtube.com/', ('youtube.com',), ()),
    'facebook': ('Facebook', 'https://www.facebook.com/login/', ('facebook.com',), ('c_user', 'xs')),
    'instagram': ('Instagram', 'https://www.instagram.com/accounts/login/', ('instagram.com',), ('ds_user_id', 'sessionid')),
    'x': ('X / Twitter', 'https://x.com/i/flow/login', ('x.com', 'twitter.com'), ('auth_token',)),
    'tiktok': ('TikTok', 'https://www.tiktok.com/login', ('tiktok.com',), ('sessionid',)),
    'twitch': ('Twitch', 'https://www.twitch.tv/login', ('twitch.tv',), ('auth-token',)),
}
_pending = {}
_lock = threading.RLock()

def cookie_path(platform):
    if platform not in PLATFORMS:
        raise ValueError('Unsupported platform')
    return app_dir() / 'cookies' / f'{platform}_connected.txt'

def begin(platform):
    cookie_path(platform)
    with _lock:
        now = time.time()
        for token in list(_pending):
            if _pending[token]['expires'] <= now or _pending[token]['platform'] == platform:
                del _pending[token]
        token = secrets.token_urlsafe(32)
        _pending[token] = {'platform': platform, 'expires': now + 600}
        return token

def pairing(token):
    with _lock:
        data = _pending.get(token)
        if not data or data['expires'] <= time.time():
            raise ValueError('Connection expired or cancelled; connect again from the app')
        platform = data['platform']
        name, url, domains, markers = PLATFORMS[platform]
        return {'platform': platform, 'name': name, 'url': url, 'domains': domains, 'markers': markers}

def receive(token, cookies, verified):
    with _lock:
        config = pairing(token)
        if verified is not True or not isinstance(cookies, list) or not 1 <= len(cookies) <= 500:
            raise ValueError('A signed-in session is required')
        rows = ['# Netscape HTTP Cookie File', '# Saved locally by Trim Playlist browser connection']
        names = set()
        now = time.time()
        for cookie in cookies:
            if not isinstance(cookie, dict):
                raise ValueError('Invalid cookie')
            domain = cookie.get('domain', '')
            name = cookie.get('name', '')
            value = cookie.get('value', '')
            path = cookie.get('path', '/')
            if not all(isinstance(v, str) and len(v) <= 16384 and not any(c in v for c in '\t\r\n\0') for v in (domain, name, value, path)):
                raise ValueError('Invalid cookie fields')
            host = domain.lstrip('.').lower()
            if not any(host == d or host.endswith('.' + d) for d in config['domains']) or not name or not path.startswith('/'):
                raise ValueError('Cookie is outside the selected platform')
            expiration = cookie.get('expirationDate', 0)
            if not isinstance(expiration, (int, float)) or not math.isfinite(expiration) or expiration < 0:
                raise ValueError('Invalid cookie expiration')
            if expiration and expiration <= now:
                continue
            names.add(name)
            include_subdomains = not cookie.get('hostOnly', not domain.startswith('.'))
            stored_domain = ('.' if include_subdomains else '') + host
            if cookie.get('httpOnly'):
                stored_domain = '#HttpOnly_' + stored_domain
            rows.append('\t'.join((stored_domain, 'TRUE' if include_subdomains else 'FALSE', path,
                                   'TRUE' if cookie.get('secure') else 'FALSE', str(int(expiration)), name, value)))
        if len(rows) == 2 or (config['markers'] and not all(marker in names for marker in config['markers'])):
            raise ValueError('No signed-in session cookies found')
        if config['platform'] == 'youtube' and not names.intersection({'SID', '__Secure-1PSID', '__Secure-3PSID'}):
            raise ValueError('No YouTube account session found')
        destination = cookie_path(config['platform'])
        destination.parent.mkdir(exist_ok=True)
        temporary = destination.with_name(destination.stem + '.' + secrets.token_hex(8) + '.tmp')
        try:
            temporary.write_text('\n'.join(rows) + '\n', encoding='utf-8')
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)
        del _pending[token]
        return {'platform': config['platform'], 'filename': destination.name}

def list_accounts():
    result = []
    with _lock:
        for platform, (name, _, _, markers) in PLATFORMS.items():
            path = cookie_path(platform)
            connected = False
            updated_at = 0
            if path.is_file():
                jar = http.cookiejar.MozillaCookieJar(str(path))
                try:
                    jar.load(ignore_discard=True, ignore_expires=True)
                    updated_at = int(path.stat().st_mtime * 1000)
                    names = {c.name for c in jar if c.expires in (None, 0) or not c.is_expired()}
                    connected = all(m in names for m in markers) if markers else bool(names.intersection({'SID', '__Secure-1PSID', '__Secure-3PSID'}))
                except (OSError, http.cookiejar.LoadError):
                    pass
            result.append({'platform': platform, 'name': name, 'connected': connected, 'filename': path.name if connected else None, 'updatedAt': updated_at if connected else 0})
    return result

def disconnect(platform):
    with _lock:
        cookie_path(platform).unlink(missing_ok=True)
        for token in list(_pending):
            if _pending[token]['platform'] == platform:
                del _pending[token]
