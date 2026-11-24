#!/usr/bin/env python3
"""Generate Japanese.lproj next to every English.lproj under a directory.

usage: make-lproj.py <dict.json>[,<dict2.json>...] <dir> [<dir> ...]
       make-lproj.py <dict.json>[,...] --dump <dir> ...   (list untranslated)

Dictionaries are merged left to right.  "_exclude": {"X.gorm": [...], "*": [...]}
lists gorm strings that must stay English (values used as identifiers).

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


def esc(text):
    """GNUstep-safe .strings text: non-ASCII as \\Uxxxx (locale independent)."""
    return "".join(c if ord(c) < 128 else "\\U%04X" % ord(c) for c in text)


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


CODE_KEY_RE = re.compile(r'(?:\b_|\bM_|NSLocalizedString)\(\s*@?"((?:[^"\\]|\\.)*)"')


CODE_TABLE_RE = re.compile(
    r'NSLocalizedStringFromTable(?:InBundle)?\(\s*@"((?:[^"\\]|\\.)*)"\s*,\s*@"([^"]+)"')


def code_tables(top):
    """{table: set(keys)} for NSLocalizedStringFromTable[InBundle] (not Localizable)."""
    tables = {}
    for root, dirs, files in os.walk(top):
        for f in files:
            if f.endswith(".m"):
                text = open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
                for m in CODE_TABLE_RE.finditer(text):
                    if m.group(2) != "Localizable":
                        tables.setdefault(m.group(2), set()).add(unq('"' + m.group(1) + '"'))
    return tables


def code_keys(top):
    keys = set()
    for root, dirs, files in os.walk(top):
        for f in files:
            if f.endswith((".m", ".h", ".c")):
                text = open(os.path.join(root, f), encoding="utf-8", errors="replace").read()
                for m in CODE_KEY_RE.finditer(text):
                    keys.add(unq('"' + m.group(1) + '"'))
    return keys


def parse_pairs(path):
    """Parse key = value pairs of a .strings file (UTF-8 or \\U escaped)."""
    raw = open(path, "rb").read()
    for enc in ("utf-8", "utf-16"):
        try:
            text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(?m)^\s*//.*$", "", text)
    tok = r'("(?:[^"\\]|\\.)*"|[^\s=;"]+)'
    pairs = []
    for m in re.finditer(tok + r"\s*(?:=\s*" + tok + r")?\s*;", text):
        k = unq(m.group(1))
        v = unq(m.group(2)) if m.group(2) else k
        pairs.append((k, v))
    return pairs


def excluded(d, gormname):
    ex = d.get("_exclude", {})
    return set(ex.get("*", [])) | set(ex.get(gormname, []))


def write_tables(en, ja, d, tables):
    """Named string tables: Japanese.lproj/<T>.strings (+ English identity
    file when missing, so both languages list the same resources)."""
    for table, keys in sorted(tables.items()):
        en_file = os.path.join(en, table + ".strings")
        if not os.path.exists(en_file):
            open(en_file, "w", encoding="ascii").write(esc(
                "/* Generated by make-lproj.py: English keys are the strings */\n"
                + "\n".join(f"{q(k)} = {q(k)};" for k in sorted(keys)) + "\n"))
        lines = [f"{q(k)} = {q(d.get(k, k))};" for k in sorted(keys)]
        open(os.path.join(ja, table + ".strings"), "w", encoding="ascii").write(esc(
            "/* Generated by Localization/Japanese/make-lproj.py */\n" + "\n".join(lines) + "\n"))
        print(f"  table {table}.strings: {sum(1 for k in keys if k in d)}/{len(keys)} translated")


def process_lproj(en, d, warns, missing, ckeys, tables=None):
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
                    # e.g. keyed-archive gorms gormtool can't read: keep English
                    print("  !! export failed, copied untranslated:", src)
                    if os.path.exists(dst):
                        shutil.rmtree(dst)
                    shutil.copytree(src, dst)
                    continue
                keys = parse_strings(exp)
                for k in keys:
                    if k.strip() and k not in d and re.search(r"[A-Za-z]{2}", k):
                        missing.add(k)
                skip = excluded(d, name)
                lines = translate_keys([k for k in keys if k not in skip], d, src, warns)
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
        elif name.endswith(".strings"):
            # translate values (by English value, then by key)
            out = []
            for k, v in parse_pairs(src):
                out.append(f"{q(k)} = {q(d.get(v, d.get(k, v)))};")
            open(dst, "w", encoding="ascii").write(esc("\n".join(out) + "\n"))
        elif os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    table = {k: v for k, v in d.items()
             if not k.startswith("_") and k != v and k in ckeys}
    en_loc = os.path.join(en, "Localizable.strings")
    if os.path.exists(en_loc):
        for k, v in parse_pairs(en_loc):
            t = d.get(v, d.get(k))
            if t is not None and not k.startswith("_"):
                table[k] = t
            elif k not in table:
                table[k] = v
    loc = [f"{q(k)} = {q(v)};" for k, v in sorted(table.items())]
    if tables:
        write_tables(en, ja, d, tables)
    open(os.path.join(ja, "Localizable.strings"), "w", encoding="ascii").write(esc(
        "/* Generated by Localization/Japanese/make-lproj.py -- edit the .json instead */\n"
        + "\n".join(loc) + "\n"))


def dump(d, tops):
    """List strings (gorm, .strings values, code keys) lacking a translation."""
    found = {}
    for top in tops:
        for k in code_keys(top):
            found.setdefault(k, "code")
        for root, dirs, files in os.walk(top):
            dirs[:] = [x for x in dirs if not x.endswith((".gorm", "obj")) or x == "English.lproj"]
            if os.path.basename(root) != "English.lproj":
                continue
            for name in os.listdir(root):
                src = os.path.join(root, name)
                if name.endswith(".gorm"):
                    with tempfile.TemporaryDirectory() as tmp:
                        exp = os.path.join(tmp, "en.strings")
                        gormtool("--read", os.path.abspath(src), "--export-strings-file", exp)
                        if os.path.exists(exp):
                            skip = excluded(d, name)
                            for k in parse_strings(exp):
                                if k not in skip:
                                    found.setdefault(k, name)
                elif name.endswith(".strings"):
                    for k, v in parse_pairs(src):
                        found.setdefault(v, name)
    todo = {k: w for k, w in found.items()
            if k.strip() and k not in d and re.search(r"[A-Za-z]{2}", k)}
    print(json.dumps(todo, ensure_ascii=False, indent=0, sort_keys=True))


def main():
    d = {}
    for jf in sys.argv[1].split(","):      # later files override earlier ones
        part = json.load(open(jf, encoding="utf-8"))
        for k, v in part.items():
            if k in ("_exclude",) and k in d:
                for g, lst in v.items():
                    d[k].setdefault(g, []).extend(lst)
            elif k == "_code_keys" and k in d:
                d[k] = d[k] + v
            else:
                d[k] = v
    if sys.argv[2] == "--dump":
        dump(d, sys.argv[3:])
        return
    warns, missing = [], set()
    for top in sys.argv[2:]:
        ckeys = code_keys(top) | set(d.get("_code_keys", []))
        tables = code_tables(top)
        unused = sorted(k for k in ckeys if k not in d and re.search(r"[A-Za-z]{2}", k))
        if unused:
            print("== code keys without translation:", unused)
        for root, dirs, files in os.walk(top):
            dirs[:] = [x for x in dirs if not x.endswith((".gorm", ".app", ".bundle", "obj"))
                       or x == "English.lproj"]
            if os.path.basename(root) == "English.lproj":
                print(root)
                process_lproj(root, d, warns, missing, ckeys, tables)
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
