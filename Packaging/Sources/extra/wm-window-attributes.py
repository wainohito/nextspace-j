#!/usr/bin/env python3
"""Add NEXTSPACE fork window attributes to the window manager's
~/Library/Preferences/.NextSpace/WMWindowAttributes.plist (the WM reloads
the file when it changes).

WebBrowserView: Chromium page windows that WebBrowser.app embeds
(cdpbridge.py starts them with --class=WebBrowserView).  No appicon, not in
window lists; they live inside WebBrowser.app's windows.

Chromium, Firefox-esr, Firefox (Mozilla's build): browser windows started
from /Applications/Chromium.app or Firefox.app.  The wrapper's appicon in
the Dock stands for them, so the browser's own appicon (which would appear
at the bottom-left corner as a second icon) is not shown.

Also drops icon entries that older WebBrowser versions left behind for each
embedded window ("text_html,_title_ASGGFD-webview-N__title.Chromium").
"""
import os
import plistlib
import shutil
import sys

ATTRS = {
    "WebBrowserView": {
        "NoAppIcon": "YES",
        "SkipWindowList": "YES",
        "SkipSwitchPanel": "YES",
        "DontSaveSession": "YES",
    },
    "Chromium": {"NoAppIcon": "YES"},
    "Firefox-esr": {"NoAppIcon": "YES"},
    "Firefox": {"NoAppIcon": "YES"},
    "firefox": {"NoAppIcon": "YES"},
}
STALE_PREFIX = "text_html,_title_ASGGFD-webview-"

path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Library/Preferences/.NextSpace/WMWindowAttributes.plist")
data = {}
if os.path.exists(path):
    with open(path, "rb") as f:
        data = plistlib.load(f)
new = dict(data)
pixmaps = os.path.expanduser("~/Library/Workspace/CachedPixmaps")
for key in [k for k in new if k.startswith(STALE_PREFIX)]:
    del new[key]
    try:
        os.unlink(os.path.join(pixmaps, key + ".tiff"))
    except OSError:
        pass
for key, attrs in ATTRS.items():
    entry = dict(new.get(key, {}))
    entry.update(attrs)
    new[key] = entry
if new == data:
    print("WMWindowAttributes: up to date")
    sys.exit(0)
if os.path.exists(path):
    shutil.copy2(path, path + ".before-nextspace-attrs")
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "wb") as f:
    plistlib.dump(new, f)
os.replace(tmp, path)
print("WMWindowAttributes: updated", path)
