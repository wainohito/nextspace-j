#!/usr/bin/env python3
"""WebBrowser.app <-> Chromium bridge using the Chrome DevTools Protocol.

Replaces the Chrome App (background.js/window.js) whose <webview> tag no
longer works in current Chromium.  It speaks the same line protocol to
WebBrowser.app (see ChromeWebView.m):

  WebBrowser -> bridge : LOAD:url BACK FORWARD CLOSE: TERMINATE: CONFIG:{json}
                         ZOOM:f EXEC:js(%-escaped) COPY CUT PASTE SELECTALL
                         FINDNEXT:text FINDPREV:text
  bridge -> WebBrowser : ON_READY:<window title> ON_LOADING_START:url
                         ON_LOADING_STOP:url ON_TITLE:title ON_NEW_WINDOW:url
                         ON_DOWNLOAD:url ON_RETURN:value(%-escaped)

usage: cdpbridge.py <AppName> [<lockfile>]
Profile: ~/Library/<AppName>/Profile; the listening port is written to
~/Library/<AppName>/controller.pid (read by ChromeController.m).
Only the Python standard library is used.
"""
import base64
import ctypes
import json
import os
import shutil
import signal
import socket
import struct
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request

DEBUG = os.environ.get("WEBBROWSER_DEBUG")


def log(*a):
    if DEBUG:
        print("cdpbridge:", *a, file=sys.stderr, flush=True)


def die_with_parent():
    """preexec_fn: let Chromium get SIGTERM if the bridge dies."""
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except OSError:
        pass


def find_chrome():
    for name in ("chromium", "google-chrome", "chromium-browser", "chrome"):
        p = shutil.which(name)
        if p:
            return p
    return None


# ---------------------------------------------------------------- WebSocket
class WebSocket:
    """Minimal RFC 6455 client (text frames, client masking)."""

    def __init__(self, url):
        u = urllib.parse.urlparse(url)
        self.sock = socket.create_connection((u.hostname, u.port))
        key = base64.b64encode(os.urandom(16)).decode()
        req = (f"GET {u.path} HTTP/1.1\r\nHost: {u.hostname}:{u.port}\r\n"
               "Upgrade: websocket\r\nConnection: Upgrade\r\n"
               f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
        self.sock.sendall(req.encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise IOError("websocket handshake failed")
            resp += chunk
        if b" 101 " not in resp.split(b"\r\n")[0]:
            raise IOError("websocket upgrade refused: %r" % resp[:80])
        self.pending = resp.split(b"\r\n\r\n", 1)[1]
        self.lock = threading.Lock()

    def _read(self, n):
        while len(self.pending) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise IOError("websocket closed")
            self.pending += chunk
        data, self.pending = self.pending[:n], self.pending[n:]
        return data

    def send(self, text):
        payload = text.encode()
        header = bytearray([0x81])
        n = len(payload)
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", n)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", n)
        mask = os.urandom(4)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        with self.lock:
            self.sock.sendall(bytes(header) + mask + masked)

    def recv(self):
        message = b""
        while True:
            b1, b2 = self._read(2)
            opcode = b1 & 0x0F
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            mask = self._read(4) if b2 & 0x80 else None
            data = self._read(n)
            if mask:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if opcode == 0x8:
                raise IOError("websocket closed by peer")
            if opcode == 0x9:  # ping -> pong
                with self.lock:
                    self.sock.sendall(bytes([0x8A, 0x80]) + os.urandom(4))
                continue
            if opcode in (0x0, 0x1, 0x2):
                message += data
                if b1 & 0x80:
                    return message.decode("utf-8", "replace")

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


class CDP:
    """A DevTools session: request/response by id plus event callback."""

    def __init__(self, url, on_event):
        self.ws = WebSocket(url)
        self.on_event = on_event
        self.next_id = 0
        self.waiting = {}
        self.cond = threading.Condition()
        self.alive = True
        threading.Thread(target=self._loop, daemon=True).start()

    def _loop(self):
        try:
            while True:
                msg = json.loads(self.ws.recv())
                if "id" in msg:
                    with self.cond:
                        self.waiting[msg["id"]] = msg
                        self.cond.notify_all()
                else:
                    try:
                        self.on_event(msg.get("method"), msg.get("params", {}))
                    except Exception as e:  # keep the session alive
                        log("event handler error", e)
        except Exception as e:
            log("cdp session ended", e)
        self.alive = False
        with self.cond:
            self.cond.notify_all()

    def call(self, method, params=None, wait=True, timeout=5.0):
        with self.cond:
            self.next_id += 1
            mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        if not wait:
            return None
        end = time.time() + timeout
        with self.cond:
            while mid not in self.waiting and self.alive and time.time() < end:
                self.cond.wait(end - time.time())
            return self.waiting.pop(mid, {}).get("result")

    def close(self):
        self.ws.close()


# ---------------------------------------------------------------- Bridge
class Bridge:
    def __init__(self, appname, lockfile=None):
        self.lockfile = lockfile
        self.closing = False   # set on TERMINATE / shutdown: open no more windows
        self.spawned = []      # "chromium --app" launcher processes
        self.proc = None
        self.browser = None
        lib = os.path.expanduser("~/Library/" + appname)
        self.profile = os.path.join(lib, "Profile")
        self.pidfile = os.path.join(lib, "controller.pid")
        os.makedirs(self.profile, exist_ok=True)
        os.makedirs(os.path.expanduser("~/Downloads"), exist_ok=True)
        self.chrome = find_chrome()
        if not self.chrome:
            print("no chromium|google-chrome|chromium-browser|chrome found!", file=sys.stderr)
            sys.exit(10)
        self.counter = 0
        self.views = {}        # targetId -> View
        self.pending = {}      # window title -> View (waiting for its target)
        self.lock = threading.Lock()
        self.zoom = 1.0

    def chrome_args(self):
        return [self.chrome, "--user-data-dir=" + self.profile, "--no-first-run",
                "--no-default-browser-check", "--disable-session-crashed-bubble",
                "--disable-features=Translate",
                # The --app windows are reparented into WebBrowser.app's
                # windows.  Until then the window manager maps them as normal
                # windows: put them off screen so nothing flashes, and give
                # them their own WM class so the WM shows no appicon for them
                # (WMWindowAttributes.plist: WebBrowserView).
                "--class=WebBrowserView", "--window-position=-10000,-10000",
                "--window-size=640,480"]

    def forget_window_placement(self):
        """Chromium restores an --app window at its last saved position,
        which overrides --window-position: drop the saved positions so the
        page windows start off screen (see chrome_args)."""
        prefs = os.path.join(self.profile, "Default", "Preferences")
        try:
            with open(prefs) as f:
                data = json.load(f)
        except (OSError, ValueError):
            return
        browser = data.get("browser")
        if not isinstance(browser, dict) or "app_window_placement" not in browser:
            return
        del browser["app_window_placement"]
        tmp = prefs + ".tmp"
        try:
            with open(tmp, "w") as f:
                json.dump(data, f, separators=(",", ":"))
            os.replace(tmp, prefs)
        except OSError:
            pass

    def start_chrome(self):
        self.forget_window_placement()
        portfile = os.path.join(self.profile, "DevToolsActivePort")
        try:
            os.unlink(portfile)
        except OSError:
            pass
        self.proc = subprocess.Popen(self.chrome_args() + ["--remote-debugging-port=0", "--silent-launch"],
                                     stdout=subprocess.DEVNULL,
                                     stderr=None if DEBUG else subprocess.DEVNULL,
                                     preexec_fn=die_with_parent)
        for _ in range(300):
            if os.path.exists(portfile):
                with open(portfile) as f:
                    lines = f.read().split()
                if len(lines) >= 2:
                    self.port = int(lines[0])
                    self.browser_ws = "ws://127.0.0.1:%d%s" % (self.port, lines[1])
                    break
            time.sleep(0.1)
        else:
            print("chromium did not start", file=sys.stderr)
            sys.exit(11)
        self.browser = CDP(self.browser_ws, self.on_browser_event)
        self.browser.call("Target.setDiscoverTargets", {"discover": True})
        self.browser.call("Browser.setDownloadBehavior", {"behavior": "deny", "eventsEnabled": True})
        log("chromium ready on port", self.port)

    def targets(self):
        try:
            with urllib.request.urlopen("http://127.0.0.1:%d/json/list" % self.port, timeout=2) as r:
                return json.load(r)
        except (OSError, ValueError):
            return []

    def chrome_running(self):
        return not self.closing and self.proc is not None and self.proc.poll() is None

    # events for all targets (title/url changes, new windows, downloads)
    def on_browser_event(self, method, params):
        if method == "Target.targetInfoChanged":
            info = params["targetInfo"]
            view = self.views.get(info["targetId"])
            if view:
                view.info_changed(info)
        elif method == "Target.targetCreated":
            info = params["targetInfo"]
            opener = self.views.get(info.get("openerId"))
            if opener and info["type"] == "page":
                # window.open / target=_blank: open as a new WebBrowser document
                threading.Thread(target=self.redirect_new_window, args=(opener, info), daemon=True).start()
        elif method == "Browser.downloadWillBegin":
            for view in list(self.views.values()):
                view.send("ON_DOWNLOAD:" + params.get("url", ""))
                break

    def redirect_new_window(self, opener, info):
        url = info.get("url") or ""
        for _ in range(20):
            if url and url != "about:blank":
                break
            time.sleep(0.1)
            for t in self.targets():
                if t["id"] == info["targetId"]:
                    url = t.get("url", "")
        self.browser.call("Target.closeTarget", {"targetId": info["targetId"]}, wait=False)
        if url and url != "about:blank":
            opener.send("ON_NEW_WINDOW:" + url)

    def serve(self):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind(("127.0.0.1", 0))
        srv.listen(8)
        with open(self.pidfile, "w") as f:
            f.write("%d\n" % srv.getsockname()[1])
        log("listening on", srv.getsockname()[1])
        threading.Thread(target=self.watch_chrome, daemon=True).start()
        threading.Thread(target=self.watch_parent, daemon=True).start()
        while True:
            conn, _ = srv.accept()
            with self.lock:
                self.counter += 1
                n = self.counter
            View(self, conn, n).start()

    def watch_chrome(self):
        self.proc.wait()
        log("chromium exited")
        self.shutdown()

    def watch_parent(self):
        # WebBrowser.app started us (via start.sh exec); quit with it, even
        # if it was killed without telling us.
        parent = os.getppid()
        while os.getppid() == parent:
            time.sleep(1)
        log("parent went away")
        self.shutdown()

    def shutdown(self, *args):
        self.closing = True
        try:
            if self.browser:
                self.browser.call("Browser.close", wait=True, timeout=2)
        except Exception:
            pass
        for p in self.spawned:
            if p.poll() is None:
                p.terminate()
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        for f in (self.lockfile, self.pidfile):
            if f:
                try:
                    os.unlink(f)
                except OSError:
                    pass
        os._exit(0)


class View:
    """One WebBrowser document <-> one Chromium app window."""

    def __init__(self, bridge, conn, n):
        self.b = bridge
        self.conn = conn
        self.title = "ASGGFD-webview-%d" % n
        self.cdp = None
        self.target = None
        self.url = ""
        self.page_title = ""
        self.ready = False
        self.queue = []
        self.send_lock = threading.Lock()

    def start(self):
        threading.Thread(target=self.read_loop, daemon=True).start()
        threading.Thread(target=self.open_window, daemon=True).start()

    def send(self, line):
        line = line.replace("\n", " ")
        with self.send_lock:
            try:
                self.conn.sendall((line + "\n").encode())
            except OSError:
                pass

    # create the app window, find its target, attach
    def open_window(self):
        # Spawning "chromium --app" while the browser is gone or closing would
        # start a new, unmanaged Chromium instance.
        if not self.b.chrome_running():
            self.close()
            return
        html = "data:text/html,<title>%s</title>" % self.title
        # Normally this hands the window over to the running browser and exits
        # at once; if it raced with browser shutdown it would become a browser
        # itself, so keep it to terminate it in Bridge.shutdown().
        self.b.spawned.append(subprocess.Popen(self.b.chrome_args() + ["--app=" + html],
                                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                               preexec_fn=die_with_parent))
        target = None
        for _ in range(100):
            for t in self.b.targets():
                if t.get("type") == "page" and t.get("title") == self.title:
                    target = t
                    break
            if target:
                break
            time.sleep(0.1)
        if not target:
            log("window not found", self.title)
            return
        self.target = target["id"]
        self.b.views[self.target] = self
        self.cdp = CDP(target["webSocketDebuggerUrl"], self.on_event)
        self.cdp.call("Page.enable")
        self.cdp.call("Runtime.enable")
        self.ready = True
        self.send("ON_READY:" + self.title)
        for cmd in self.queue:
            self.command(cmd)
        self.queue = []

    def read_loop(self):
        buf = b""
        try:
            while True:
                data = self.conn.recv(65536)
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    cmd = line.decode("utf-8", "replace")
                    if self.ready:
                        self.command(cmd)
                    else:
                        self.queue.append(cmd)
        except OSError:
            pass
        self.close()

    def evaluate(self, js, wait=False):
        if self.cdp:
            r = self.cdp.call("Runtime.evaluate", {"expression": js, "returnByValue": True,
                                                    "userGesture": True}, wait=wait)
            return r

    def key(self, key, code, keycode):
        for t in ("keyDown", "keyUp"):
            self.cdp.call("Input.dispatchKeyEvent", {"type": t, "modifiers": 2, "key": key,
                                                     "code": code,
                                                     "windowsVirtualKeyCode": keycode}, wait=False)

    def apply_zoom(self):
        self.evaluate("document.documentElement.style.zoom=%f" % self.b.zoom)

    def command(self, cmd):
        name, _, val = cmd.partition(":")
        log(self.title, "cmd", name, val[:80])
        if name == "LOAD":
            # WebBrowser sends local files as file://<fileserver-port>/path (for
            # the old Chrome App); Chromium can open file:///path directly.
            if val.startswith("file://"):
                host, _, path = val[7:].partition("/")
                if host.isdigit():
                    val = "file:///" + path
            self.cdp.call("Page.navigate", {"url": val}, wait=False)
        elif name == "BACK":
            self.evaluate("history.back()")
        elif name == "FORWARD":
            self.evaluate("history.forward()")
        elif name == "CLOSE":
            self.close()
        elif name == "TERMINATE":
            self.b.closing = True
            self.b.browser.call("Browser.close", wait=False)
        elif name == "CONFIG":
            try:
                self.b.zoom = float(json.loads(val).get("zoom", 1.0))
            except ValueError:
                pass
            self.apply_zoom()
        elif name == "ZOOM":
            try:
                self.b.zoom = float(val)
            except ValueError:
                pass
            self.apply_zoom()
        elif name == "EXEC":
            js = urllib.parse.unquote(val)
            r = self.evaluate(js, wait=True) or {}
            v = r.get("result", {}).get("value", "")
            if not isinstance(v, str):
                v = json.dumps(v)
            self.send("ON_RETURN:" + urllib.parse.quote(v))
        elif name == "COPY":
            self.key("c", "KeyC", 67)
        elif name == "CUT":
            self.key("x", "KeyX", 88)
        elif name == "PASTE":
            self.key("v", "KeyV", 86)
        elif name == "SELECTALL":
            self.key("a", "KeyA", 65)
        elif name in ("FINDNEXT", "FINDPREV"):
            back = "true" if name == "FINDPREV" else "false"
            self.evaluate("window.find(%s,false,%s,true)" % (json.dumps(val), back))

    def on_event(self, method, params):
        if method == "Page.frameStartedLoading" and params.get("frameId") == self.target:
            self.send("ON_LOADING_START:" + self.url)
        elif method in ("Page.loadEventFired",):
            self.apply_zoom()
            self.send("ON_LOADING_STOP:" + self.url)
        elif method == "Page.frameNavigated" and not params["frame"].get("parentId"):
            self.url = params["frame"].get("url", self.url)
            self.send("ON_LOADING_START:" + self.url)
        elif method == "Page.navigatedWithinDocument":
            self.url = params.get("url", self.url)
            self.send("ON_LOADING_STOP:" + self.url)

    def info_changed(self, info):
        url = info.get("url", "")
        title = info.get("title", "")
        if url and url != self.url and not url.startswith("data:"):
            self.url = url
        if title and title != self.page_title and title != self.title:
            self.page_title = title
            self.send("ON_TITLE:" + title)

    def close(self):
        if self.target:
            self.b.browser.call("Target.closeTarget", {"targetId": self.target}, wait=False)
            self.b.views.pop(self.target, None)
            self.target = None
        if self.cdp:
            self.cdp.close()
        try:
            self.conn.close()
        except OSError:
            pass


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    bridge = Bridge(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    signal.signal(signal.SIGTERM, bridge.shutdown)
    signal.signal(signal.SIGINT, bridge.shutdown)
    bridge.start_chrome()
    try:
        bridge.serve()
    finally:
        bridge.shutdown()


if __name__ == "__main__":
    main()
