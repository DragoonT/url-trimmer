import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

import pc.accounts.account_connections as accounts
import pc.server.playlist_server as playlist_server


class AccountConnectionTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.paths = patch.object(accounts, 'app_dir', lambda: self.root)
        self.paths.start()
        accounts._pending.clear()

    def tearDown(self):
        self.paths.stop()
        self.folder.cleanup()

    def cookies(self, domain='.facebook.com'):
        return [dict(domain=domain, name=name, value='test-only', path='/',
                     hostOnly=False, secure=True, httpOnly=True)
                for name in ('c_user', 'xs')]

    def test_saved_session_round_trip_and_one_use_pairing(self):
        token = accounts.begin('facebook')
        result = accounts.receive(token, self.cookies(), True)
        self.assertEqual(result['filename'], 'facebook_connected.txt')
        self.assertTrue(next(a for a in accounts.list_accounts() if a['platform'] == 'facebook')['connected'])
        with self.assertRaises(ValueError):
            accounts.receive(token, self.cookies(), True)
        text = accounts.cookie_path('facebook').read_text()
        self.assertIn('#HttpOnly_.facebook.com', text)
        self.assertEqual(list((self.root / 'cookies').glob('*.tmp')), [])

    def test_rejects_other_platform_and_line_injection(self):
        token = accounts.begin('facebook')
        with self.assertRaises(ValueError):
            accounts.receive(token, self.cookies('.instagram.com'), True)
        cookies = self.cookies()
        cookies[0]['value'] = 'value\n.injected.com\tTRUE'
        with self.assertRaises(ValueError):
            accounts.receive(token, cookies, True)
        self.assertFalse(accounts.cookie_path('facebook').exists())

    def test_unsigned_expired_and_disconnected_pairs_cannot_save(self):
        token = accounts.begin('facebook')
        with self.assertRaises(ValueError):
            accounts.receive(token, self.cookies(), False)
        accounts._pending[token]['expires'] = 0
        with self.assertRaises(ValueError):
            accounts.receive(token, self.cookies(), True)
        token = accounts.begin('facebook')
        accounts.disconnect('facebook')
        with self.assertRaises(ValueError):
            accounts.receive(token, self.cookies(), True)

    def test_disconnect_removes_only_connected_session(self):
        token = accounts.begin('facebook')
        accounts.receive(token, self.cookies(), True)
        manual = self.root / 'cookies' / 'facebook_cookie.txt'
        manual.write_text('manual test file')
        accounts.disconnect('facebook')
        self.assertFalse(accounts.cookie_path('facebook').exists())
        self.assertTrue(manual.exists())

    def test_http_rejects_foreign_origin_and_accepts_paired_callback(self):
        server, port = playlist_server.create_server_on_port('127.0.0.1', 8890)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        origin = f'http://127.0.0.1:{port}'
        def post(path, data, headers=None):
            request = urllib.request.Request(origin + path, data=json.dumps(data).encode(),
                headers={'Content-Type': 'application/json', **(headers or {})}, method='POST')
            with urllib.request.urlopen(request, timeout=3) as response:
                return json.load(response)
        try:
            with self.assertRaises(urllib.error.HTTPError) as caught:
                post('/api/accounts/connect', {'platform': 'facebook'},
                     {'Origin': 'https://untrusted.example', 'X-Trim-Playlist': '1'})
            self.assertEqual(caught.exception.code, 403)
            caught.exception.close()
            with self.assertRaises(urllib.error.HTTPError) as invalid:
                post('/api/accounts/connect', [], {'Origin': origin, 'X-Trim-Playlist': '1'})
            self.assertEqual(invalid.exception.code, 400)
            invalid.exception.close()
            pair = post('/api/accounts/connect', {'platform': 'facebook'},
                        {'Origin': origin, 'X-Trim-Playlist': '1'})
            result = post('/api/accounts/pair/' + pair['token'],
                          {'cookies': self.cookies(), 'verified': True})
            self.assertEqual(result['platform'], 'facebook')
            with urllib.request.urlopen(origin + '/api/accounts', timeout=3) as response:
                status = json.load(response)
            self.assertTrue(any(a['platform'] == 'facebook' and a['connected'] for a in status))
            self.assertNotIn('test-only', json.dumps(status))
        finally:
            playlist_server.stop_server(server, thread)


if __name__ == '__main__':
    unittest.main()
