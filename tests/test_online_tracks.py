import unittest
from unittest.mock import patch

import pc.downloads.online_media as online_media


class OnlineTrackTests(unittest.TestCase):
    def preview(self):
        return {
            "status": "complete",
            "is_playlist": True,
            "cookies": "youtube.txt",
            "items": [
                {"index": 1, "title": "First", "url": "https://example.test/watch/1", "available": True},
                {"index": 2, "title": "Private", "url": "https://example.test/watch/2", "available": False},
                {"index": 3, "title": "Third", "url": "https://example.test/watch/3", "available": True, "duration": 10},
            ],
        }

    def test_builds_selected_online_tracks_without_local_file(self):
        tracks = online_media.build_online_items(
            {"indexes": [3], "playback": "audio", "title": "My title"}, self.preview()
        )
        self.assertEqual(tracks, [{
            "source": "online", "url": "https://example.test/watch/3", "title": "My title",
            "cookies": "youtube.txt", "kind": "audio", "duration": 10, "ext": "stream",
        }])
        self.assertNotIn("file", tracks[0])
        self.assertNotIn("path", tracks[0])

    def test_rejects_unavailable_or_unloaded_selection(self):
        with self.assertRaises(ValueError):
            online_media.build_online_items({"indexes": [2]}, self.preview())
        with self.assertRaises(ValueError):
            online_media.build_online_items({"indexes": [1]}, {"status": "running"})
        with self.assertRaises(ValueError):
            online_media.build_online_items({"indexes": [1], "playback": "mp3"}, self.preview())

    def test_requested_video_quality_is_used_for_online_stream(self):
        captured = {}

        class Downloader:
            def __init__(self, options):
                captured.update(options)
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def extract_info(self, url, download=False):
                return {"url": "https://cdn.example.test/video.mp4", "ext": "mp4", "height": 720, "http_headers": {}}

        online_media._cache.clear()
        with patch("yt_dlp.YoutubeDL", Downloader):
            stream = online_media.resolve_stream({"url": "https://example.test/watch", "kind": "video"}, "720")
        self.assertIn("height=720", captured["format"])
        self.assertEqual(stream["mime"], "video/mp4")


if __name__ == "__main__":
    unittest.main()
