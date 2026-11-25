#!/usr/bin/env python3
"""Window manager (Workspace WM) settings of the NEXTSPACE fork, in
~/Library/Preferences/.NextSpace:

WM.plist: Japanese fonts for window titles, menus and icon titles (the
default fonts have no Japanese glyphs, so titles showed boxes).

WMState.plist: Firefox, Chromium, WebBrowser and wmsystemtray (input
method and volume tray icons, started by nextspace-autostart) in the Dock,
below TextEdit.  The WM writes its state back when the session ends, so
run this before Workspace starts: install.sh does it when nobody is logged
in, otherwise nextspace-autostart runs it at the next login
(~/.local/state/nextspace/wm-setup-pending).

WMWindowAttributes.plist (the WM reloads it when it changes):

WebBrowserView: Chromium page windows that WebBrowser.app embeds
(cdpbridge.py starts them with --class=WebBrowserView).  No appicon, not in
window lists; they live inside WebBrowser.app's windows.

Wrapper_Firefox, Wrapper_Chromium: browser windows started from
/Applications/Firefox.app or Chromium.app (--class Wrapper_...).  The wrapper's appicon in
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
    # Browser windows started by /Applications/Firefox.app / Chromium.app
    # (--class Wrapper_...): the wrapper's appicon in the Dock stands for them.
    # NoAppMenu: the wrapper shows its own (Japanese) menu for them, so the
    # WM's application menu for X11 apps would be a second one.
    "Wrapper_Firefox": {"NoAppIcon": "YES", "NoAppMenu": "YES"},
    "Wrapper_Chromium": {"NoAppIcon": "YES", "NoAppMenu": "YES"},
}
# Attributes set by earlier versions that must go.
# ("Firefox"/"Chromium" also matched the wrappers' own instance names and hid
# their appicons, so the docked icons never showed "running".)
REMOVE = {
    "Chromium": ["NoAppIcon"],
    "Firefox": ["NoAppIcon"],
    "chromium.Chromium": ["NoAppIcon"],
    "Firefox-esr": ["NoAppIcon"],
    "firefox-esr": ["NoAppIcon"],
    "firefox": ["NoAppIcon"],
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

def _dock_app(name, command, slot):
    return {"AutoLaunch": "No", "BuggyApplication": "No", "Forced": "No", "Lock": "No",
            "Name": name, "Command": command, "DropCommand": command + " %d",
            "PasteCommand": command + " %s", "Position": "0,%d" % slot}


# Dock below TextEdit (slot 4), in this order.  Entries with these names are
# (re)placed here on every run.
DOCK_APPS = [
    _dock_app("Firefox.GNUstep", "/Applications/Firefox.app/Firefox", 5),
    _dock_app("Chromium.GNUstep", "/Applications/Chromium.app/Chromium", 6),
    _dock_app("WebBrowser.GNUstep", "/Applications/WebBrowser.app/WebBrowser", 7),
    _dock_app("wmsystemtray0.wmsystemtray", "wmsystemtray", 8),
]
DOCK_NAMES = {a["Name"] for a in DOCK_APPS}

# Icons of docked applications that are not running yet.
ICONS = {
    # Default Dock applications (as in /etc/skel); without them the Dock shows
    # "?" until each application has run once and its icon is cached.
    "Preferences.GNUstep": "/Applications/Preferences.app/Resources/English.lproj/Preferences.tiff",
    "Terminal.GNUstep": "/Applications/Terminal.app/Resources/Terminal.tiff",
    "TextEdit.GNUstep": "/Applications/TextEdit.app/Resources/Edit.tiff",
    "TimeMon.GNUstep": "/Applications/TimeMon.app/Resources/TM-app.tiff",
    "Firefox.GNUstep": "/Applications/Firefox.app/Resources/AppIcon.tiff",
    "Chromium.GNUstep": "/Applications/Chromium.app/Resources/AppIcon.tiff",
    "WebBrowser.GNUstep": "/Applications/WebBrowser.app/Resources/WebBrowser.tiff",
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

# WMState.plist: browsers and wmsystemtray in the Dock (every per-resolution
# app list; "Applications" is the fallback when none matches the screen)
def slot_of(app):
    try:
        return int(str(app.get("Position", "")).split(",")[1])
    except (IndexError, ValueError):
        return None


path = os.path.join(PREFS, "WMState.plist")
SKEL = "/etc/skel/Library/Preferences/.NextSpace"
for name in ("WMState.plist", "WMWindowAttributes.plist"):
    # Start from the NEXTSPACE defaults when the WM has not written its own.
    if not os.path.exists(os.path.join(PREFS, name)) and os.path.exists(os.path.join(SKEL, name)):
        os.makedirs(PREFS, exist_ok=True)
        shutil.copy(os.path.join(SKEL, name), os.path.join(PREFS, name))
data = load(path)
dock = data.get("Dock")
if isinstance(dock, dict):
    new = dict(data)
    new["Dock"] = dict(dock)
    for key, apps in dock.items():
        if not key.startswith("Applications") or not isinstance(apps, list):
            continue
        height = key[len("Applications"):]
        last = (int(height) if height.isdigit() else 768) // 64 - 1  # Recycler slot
        apps = [dict(a) for a in apps if a.get("Name") not in DOCK_NAMES]
        for a in apps:
            if a.get("Name") == "Recycler.GNUstep":
                a["Position"] = "0,%d" % last
        used = {slot_of(a) for a in apps}
        for want in DOCK_APPS:
            slot = slot_of(want)
            while slot in used:
                slot += 1
            if slot >= last:
                print("Dock (%s): no room for %s" % (key, want["Name"]))
                continue
            used.add(slot)
            apps.append(dict(want, Position="0,%d" % slot))
        new["Dock"][key] = apps
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
for key, icon in ICONS.items():
    if "Icon" not in new.get(key, {}) and os.path.exists(icon):
        new[key] = dict(new.get(key, {}), Icon=icon)
for key, names in REMOVE.items():
    if isinstance(new.get(key), dict) and any(n in new[key] for n in names):
        entry = {k: v for k, v in new[key].items() if k not in names}
        if entry:
            new[key] = entry
        else:
            del new[key]
for key, attrs in ATTRS.items():
    entry = dict(new.get(key, {}))
    entry.update(attrs)
    new[key] = entry
save(path, data, new, "WMWindowAttributes.plist")
