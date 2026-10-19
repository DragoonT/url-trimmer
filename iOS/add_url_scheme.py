"""Add the fixed Trim Playlist callback scheme to a built IPA.

The Windows builder generates Info.plist itself. This post-build step makes the
scheme visible to iOS; a device installer must subsequently apply a real Apple
signature to the IPA.
"""
from __future__ import annotations

import plistlib
import sys
from pathlib import Path
from tempfile import NamedTemporaryFile
from zipfile import ZIP_DEFLATED, ZipFile


ipa = Path(sys.argv[1])
plist_name = "Payload/TrimPlaylist.app/Info.plist"
with ZipFile(ipa, "r") as archive:
    items = [(entry, archive.read(entry.filename)) for entry in archive.infolist()]

for index, (entry, contents) in enumerate(items):
    if entry.filename != plist_name:
        continue
    data = plistlib.loads(contents)
    data["CFBundleURLTypes"] = [{"CFBundleURLName": "Trim Playlist callback", "CFBundleURLSchemes": ["trimplaylist"]}]
    data["UIBackgroundModes"] = ["audio"]
    data["NSAppTransportSecurity"] = {"NSAllowsArbitraryLoads": True}
    items[index] = (entry, plistlib.dumps(data, fmt=plistlib.FMT_XML, sort_keys=False))
    break
else:
    raise SystemExit(f"{plist_name} is missing from {ipa}")

with NamedTemporaryFile(delete=False, suffix=".ipa", dir=ipa.parent) as temp:
    temp_path = Path(temp.name)
with ZipFile(temp_path, "w", compression=ZIP_DEFLATED) as archive:
    for entry, contents in items:
        archive.writestr(entry, contents)
temp_path.replace(ipa)
