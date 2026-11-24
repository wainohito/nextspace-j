#!/usr/bin/env python3
"""Generate Japanese.lproj next to every English.lproj under a directory.

usage: make-lproj.py <dictionary.json> <dir> [<dir> ...]

* *.gorm      : strings are exported with gormtool, translated with the
                dictionary and imported into a copy saved in Japanese.lproj.
* Localizable.strings / other *.strings : translated by key.
* other files : copied as-is (gnustep-make expects every localized resource
                to exist for each language).
A Localizable.strings is (re)generated in each Japanese.lproj containing only
the dictionary entries whose key is used in the sources (_(@"..."),
NSLocalizedString(@"...")) plus "_code_keys" from the dictionary.  Never put
identifiers (defaults values, type names) through _() -- they'd be translated.

Strings whose Japanese rendering is estimated to be wider than the English
original are reported, so fixed-size layouts can be checked.
"""
import json, os, re, shutil, subprocess, sys, tempfile, unicodedata

GORMTOOL = "/Developer/bin/gormtool"


def width(s):
    """Rough pixel width at 12pt: CJK/full-width ~12px, others ~6.5px."""
    w = 0.0
    for ch in s:
        w += 12.0 if unicodedata.east_asian_width(ch) in "WF" else 6.5
    return w


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def parse_strings(path):
    """Parse a simple .strings file (the format gormtool exports) via plutil-like rules."""
    text = open(path, encoding="utf-8", errors="replace").read()
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    tok = re.compile(r'\s*("(?:[^"\\]|\\.)*"|[^\s=;"]+)\s*')
    out, pos = [], 0
    while True:
        m = tok.match(text, pos)
        if not m or not m.group(1):
            break
        key = m.group(1)
        pos = m.end()
        if text.startswith("=", pos):
            m2 = tok.match(text, pos + 1)
            pos = m2.end()
        if text.startswith(";", pos):
            pos += 1
        out.append(unq(key))
    return out


def unq(s):
    if s.startswith('"'):
        s = s[1:-1]
        s = re.sub(r"\\(u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{4}|.)",
                   lambda m: chr(int(m.group(1)[1:], 16)) if len(m.group(1)) == 5
                   else {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)
    return s


def gormtool(*args):
    env = dict(os.environ)
    r = subprocess.run([GORMTOOL, *args], env=env, capture_output=True, text=True, timeout=60)
    return r


def translate_keys(keys, d, where, warns):
    lines = []
    for k in keys:
        if k in d and d[k] != k:
            lines.append(f"{q(k)} = {q(d[k])};")
            if width(d[k]) > width(k) * 1.05 and width(d[k]) - width(k) > 6:
                warns.append((where, k, d[k], int(width(k)), int(width(d[k]))))
    return lines


CODE_KEY_RE = re.compile(r'(?:\b_|NSLocalizedString)\(\s*@"((?:[^"\\]|\\.)*)"')


def code_keys(top):
    keys = set()
    for root, dirs, files in os.walk(top):
        for f in files:
            if f.endswith((".m", ".h")):
                text = open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
                for m in CODE_KEY_RE.finditer(text):
                    keys.add(unq('"' + m.group(1) + '"'))
    return keys


def process_lproj(en, d, warns, missing, ckeys):
    ja = os.path.join(os.path.dirname(en), "Japanese.lproj")
    os.makedirs(ja, exist_ok=True)
    for name in sorted(os.listdir(en)):
        src = os.path.join(en, name)
        dst = os.path.join(ja, name)
        if name.endswith(".gorm"):
            with tempfile.TemporaryDirectory() as tmp:
                exp = os.path.join(tmp, "en.strings")
                gormtool("--read", os.path.abspath(src), "--export-strings-file", exp)
                if not os.path.exists(exp):
                    print("  !! export failed:", src)
                    continue
                keys = parse_strings(exp)
                for k in keys:
                    if k.strip() and k not in d and re.search(r"[A-Za-z]{2}", k):
                        missing.add(k)
                lines = translate_keys(keys, d, src, warns)
                imp = os.path.join(tmp, "ja.strings")
                open(imp, "w", encoding="utf-8").write("\n".join(lines) + "\n")
                if os.path.exists(dst):
                    shutil.rmtree(dst)
                r = gormtool("--read", os.path.abspath(src), "--import-strings-file", imp,
                             "--write", os.path.abspath(dst))
                if not os.path.isdir(dst):
                    print("  !! write failed:", src, r.stderr[-300:])
                else:
                    print(f"  {name}: {len(lines)}/{len(set(keys))} translated")
        elif name == "Localizable.strings":
            continue  # regenerated below
        elif os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    loc = [f"{q(k)} = {q(v)};" for k, v in sorted(d.items())
           if not k.startswith("_") and k != v and k in ckeys]
    open(os.path.join(ja, "Localizable.strings"), "w", encoding="utf-8").write(
        "/* Generated by Localization/Japanese/make-lproj.py -- edit the .json instead */\n"
        + "\n".join(loc) + "\n")


def main():
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    warns, missing = [], set()
    for top in sys.argv[2:]:
        ckeys = code_keys(top) | set(d.get("_code_keys", []))
        unused = sorted(k for k in ckeys if k not in d and re.search(r"[A-Za-z]{2}", k))
        if unused:
            print("== code keys without translation:", unused)
        for root, dirs, files in os.walk(top):
            dirs[:] = [x for x in dirs if not x.endswith((".gorm", ".app", ".bundle", "obj"))
                       or x == "English.lproj"]
            if os.path.basename(root) == "English.lproj":
                print(root)
                process_lproj(root, d, warns, missing, ckeys)
                dirs[:] = []
    if warns:
        print("\n== Possibly too wide (en px -> ja px):")
        for w, k, v, a, b in warns:
            print(f"  {os.path.basename(os.path.dirname(w))}/{os.path.basename(w)}: {k!r} -> {v!r} ({a} -> {b})")
    if missing:
        print("\n== Untranslated:")
        for k in sorted(missing):
            print("  ", repr(k))


if __name__ == "__main__":
    main()
