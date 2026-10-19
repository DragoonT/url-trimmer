import tempfile
import unittest
from pathlib import Path

import playlist_server


class CookieFileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.folder = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_manual_name_and_text_round_trip(self):
        name = playlist_server.save_cookie_text(self.folder, " youtube ", "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t0\tSID\tvalue\n")
        self.assertEqual(name, "youtube.txt")
        self.assertIn("SID\tvalue", playlist_server.read_cookie_text(self.folder, name))

    def test_blank_name_becomes_cookies_txt(self):
        self.assertEqual(playlist_server.save_cookie_text(self.folder, "  ", "session"), "cookies.txt")
        self.assertEqual(playlist_server.save_cookie_text(self.folder, "notes.txt", "imported"), "notes.txt")

    def test_rejects_paths_and_reserved_names(self):
        for name in ("../secret", "readme", "con", "bad:name", "nested/file"):
            with self.assertRaises(ValueError):
                playlist_server.save_cookie_text(self.folder, name, "text")
        self.assertFalse(any(self.folder.rglob("*")))


if __name__ == "__main__":
    unittest.main()
