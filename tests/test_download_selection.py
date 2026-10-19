import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
import download_jobs as downloads
import yt_dlp


class FakeDownloader(yt_dlp.YoutubeDL):
    calls = []
    exports = []
    def __init__(self, options):
        super().__init__(options)
        self.options = options
        self.params = options
        self.processor = None
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def add_post_processor(self, processor, **kwargs): self.processor = processor
    def extract_info(self, url, download=False):
        self.calls.append(('preview', self.options, download))
        return {'_type': 'playlist', 'title': 'Example', 'entries': [
            {'url': 'https://example.com/1', 'title': 'First'},
            {'url': 'https://example.com/2', 'title': '[Deleted video]'},
            {'url': 'https://example.com/3', 'title': 'Third'}]}
    def download(self, urls):
        self.calls.append(('download', self.options, urls))
        indexes = [int(i) for i in self.options['playlist_items'].split(',')] if self.options.get('playlist_items') else [1, 2, 3]
        for index in indexes:
            info = {'id': str(index), 'title': 'Item ' + str(index), 'filepath': 'fake.mp4',
                    'duration': 1, 'playlist_index': index, 'playlist_count': 3}
            self.processor.run(info)


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.paths = patch.object(downloads, 'app_dir', lambda: Path(self.temp.name))
        self.paths.start()
        FakeDownloader.calls = []
        self.downloader = patch('yt_dlp.YoutubeDL', FakeDownloader)
        self.downloader.start()
        self.positions = []
        def export(cmd, destination, duration, progress):
            progress(50)
            with downloads.lock:
                latest = list(downloads.jobs.values())[-1]
                self.positions.append((latest['item'], latest['total']))
            progress(100)
        self.export = patch.object(downloads, 'export_with_progress', export)
        self.export.start()
    def tearDown(self):
        self.export.stop(); self.downloader.stop(); self.paths.stop(); self.temp.cleanup()
    def wait(self, job):
        for _ in range(300):
            result = downloads.get_job(job)
            if result['status'] != 'running':
                self.assertEqual(result['status'], 'complete', result)
                return result
            time.sleep(.01)
        self.fail('Job did not finish')
    def data(self, **kwargs):
        return {'url': 'https://example.com/playlist', 'format': 'mp3', 'auth_source': 'none', **kwargs}
    def test_single_request_never_downloads_whole_playlist(self):
        result = self.wait(downloads.start_download(self.data()))
        self.assertEqual(len(result['files']), 1)
        self.assertEqual(FakeDownloader.calls[-1][1]['playlist_items'], '1')
        self.assertEqual(self.positions, [(1, 1)])
    def test_selected_indices_and_progress_count(self):
        result = self.wait(downloads.start_download(self.data(selected_items=[3])))
        self.assertEqual(result['files'], ['Item 3.mp3'])
        self.assertEqual(self.positions, [(1, 1)])
        self.positions.clear()
        self.wait(downloads.start_download(self.data(selected_items=[2, 3])))
        self.assertEqual(self.positions, [(1, 2), (2, 2)])
    def test_entire_playlist_remains_explicit(self):
        result = self.wait(downloads.start_download(self.data(playlist=True)))
        self.assertEqual(len(result['files']), 3)
        self.assertEqual(self.positions, [(1, 3), (2, 3), (3, 3)])
    def test_preview_lists_items_without_download(self):
        result = self.wait(downloads.preview_download(self.data()))
        self.assertTrue(result['is_playlist'])
        self.assertEqual([i['available'] for i in result['items']], [True, False, True])
        self.assertEqual([c[0] for c in FakeDownloader.calls], ['preview'])
        self.assertFalse(FakeDownloader.calls[0][2])
        self.assertFalse(FakeDownloader.calls[0][1]['noplaylist'])
    def test_invalid_selection_and_trim_multiple_rejected(self):
        for value in ([], [0], [True], ['1']):
            with self.assertRaises(ValueError): downloads.start_download(self.data(selected_items=value))
        with self.assertRaises(ValueError):
            downloads.start_download(self.data(mode='trim', start='0:00', end='0:10', selected_items=[1, 2]))
    def test_cookie_and_platform_are_separate(self):
        self.assertIsNone(downloads.download_cookie_path({'auth_source': 'none', 'cookies': 'missing.txt'}))
        with self.assertRaises(ValueError): downloads.download_cookie_path({'cookies': '../secret.txt'})
        with self.assertRaises(ValueError): downloads.download_cookie_path({'auth_source': 'invalid'})
        import account_connections
        cookie = Path(self.temp.name) / 'connected.txt'; cookie.write_text('test')
        with patch.object(account_connections, 'cookie_path', return_value=cookie), patch.object(account_connections, 'list_accounts', return_value=[{'platform': 'youtube', 'connected': True}]):
            self.assertEqual(downloads.download_cookie_path({'auth_source': 'platform', 'platform': 'youtube', 'cookies': 'missing.txt'}), cookie)
            self.assertEqual(downloads.download_cookie_path({'auth_source': 'extension', 'platform': 'youtube', 'cookies': 'missing.txt'}), cookie)


if __name__ == '__main__': unittest.main()
