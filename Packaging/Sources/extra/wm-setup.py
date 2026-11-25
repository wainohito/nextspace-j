#!/usr/bin/env python3
"""Window manager (Workspace WM) settings of the NEXTSPACE fork, in
~/Library/Preferences/.NextSpace:

WM.plist: Japanese fonts for window titles, menus and icon titles (the
default fonts have no Japanese glyphs, so titles showed boxes).

WMState.plist: dock wmsystemtray (input method and volume tray icons,
started by nextspace-autostart) in the Dock instead of leaving it at the
bottom-left corner.  Run it while you are logged out: the WM saves its
state over this file when the session ends.

WMWindowAttributes.plist (the WM reloads it when it changes):

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

PREFS = os.path.expanduser("~/Library/Preferences/.NextSpace")


def _font(name, size):
    return ("NotoSansCJKjp:postscriptname=%s:pixelsize=%d:antialias=true:"
            "embeddedbitmap=false" % (name, size))


WM_FONTS = {
    "WindowTitleFont": _font("NotoSansCJKjp-Bold", 12),
    "MenuTitleFont": _font("NotoSansCJKjp-Bold", 12),
    "MenuTextFont": _font("NotoSansCJKjp-Regular", 12),
    "IconTitleFont": _font("NotoSansCJKjp-Regular", 9),
    "LargeDisplayFont": _font("NotoSansCJKjp-Regular", 24),
}

TRAY = {
    "AutoLaunch": "No", "BuggyApplication": "No", "Forced": "No", "Lock": "No",
    "Command": "wmsystemtray", "DropCommand": "wmsystemtray %d",
    "PasteCommand": "wmsystemtray %s", "Name": "wmsystemtray0.wmsystemtray",
}


def load(path):
    if os.path.exists(path):
        with open(path, "rb") as f:
            return plistlib.load(f)
    return {}


def save(path, old, new, what):
    if new == old:
        print(what + ": up to date")
        return
    if os.path.exists(path):
        shutil.copy2(path, path + ".before-nextspace-setup")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        plistlib.dump(new, f)
    os.replace(tmp, path)
    print(what + ": updated", path)


# WM.plist: fonts
path = os.path.join(PREFS, "WM.plist")
data = load(path)
new = dict(data)
new.update(WM_FONTS)
save(path, data, new, "WM.plist")

# WMState.plist: wmsystemtray in the Dock (every per-resolution app list)
path = os.path.join(PREFS, "WMState.plist")
data = load(path)
dock = data.get("Dock")
if isinstance(dock, dict):
    new = dict(data)
    new["Dock"] = dict(dock)
    for key, apps in dock.items():
        if not key.startswith("Applications") or not isinstance(apps, list):
            continue
        if any(a.get("Name") == TRAY["Name"] for a in apps):
            continue
        used = set()
        recycler = None
        for a in apps:
            try:
                n = int(str(a.get("Position", "")).split(",")[1])
            except (IndexError, ValueError):
                continue
            used.add(n)
            if a.get("Name") == "Recycler.GNUstep":
                recycler = n
        last = max([n for n in used if n != recycler] or [0])
        slot = last + 1
        while slot in used:
            slot += 1
        if recycler is not None and slot >= recycler:
            continue  # no free slot above the Recycler
        new["Dock"][key] = apps + [dict(TRAY, Position="0,%d" % slot)]
    save(path, data, new, "WMState.plist (Dock)")
else:
    print("WMState.plist: no Dock yet, skipped")

# WMWindowAttributes.plist
path = os.path.join(PREFS, "WMWindowAttributes.plist")
data = load(path)
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
save(path, data, new, "WMWindowAttributes.plist")
