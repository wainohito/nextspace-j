#!/usr/bin/env python3
"""Turn non-localized gorm resources into localized ones.

usage: lprojify.py <dir> [<dir> ...]

For every GNUmakefile under <dir> whose *_RESOURCE_FILES list contains
"Resources/<name>.gorm" (or "<name>.gorm"), the gorm is moved (git mv) to
English.lproj/ next to the GNUmakefile, removed from *_RESOURCE_FILES and
added to *_LOCALIZED_RESOURCE_FILES; *_LANGUAGES becomes "English Japanese".
Then make-lproj.py can create Japanese.lproj.
"""
import os
import re
import subprocess
import sys


def logical_lines(text):
    """Yield (start, end, joined) for makefile logical lines."""
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        start = i
        buf = [lines[i]]
        while buf[-1].endswith("\\") and i + 1 < len(lines):
            i += 1
            buf.append(lines[i])
        yield start, i, buf
        i += 1


def process(mk):
    d = os.path.dirname(mk)
    text = open(mk).read()
    lines = text.split("\n")
    moved = {}  # prefix -> [gorm names]
    new_lines = []
    for start, end, buf in logical_lines(text):
        m = re.match(r"^(\$\(\w+\)|[A-Za-z0-9_.-]+)_RESOURCE_FILES\s*\+?=", buf[0])
        if not m or "LOCALIZED" in buf[0]:
            new_lines.extend(buf)
            continue
        prefix = m.group(1)
        kept = []
        for idx, line in enumerate(buf):
            body = line.rstrip().rstrip("\\").strip()
            head = ""
            if idx == 0:
                head, _, body = body.partition("=")
                head += "="
            keep_tokens = []
            for t in body.split():
                g = re.match(r"^(?:Resources/)?([A-Za-z0-9_+-]+\.gorm)$", t)
                if g and os.path.isdir(os.path.join(d, t)):
                    moved.setdefault(prefix, []).append((t, g.group(1)))
                    continue
                keep_tokens.append(t)
            cont = " \\" if line.rstrip().endswith("\\") else ""
            if idx == 0:
                kept.append((head + " " + " ".join(keep_tokens)).rstrip() + cont)
            elif keep_tokens:
                kept.append(" ".join(keep_tokens) + cont)
        # make sure the last kept line does not end with a continuation
        if kept and kept[-1].rstrip().endswith("\\") and len(kept) > 1:
            kept[-1] = kept[-1].rstrip().rstrip("\\").rstrip()
        new_lines.extend(kept)
        if prefix in moved:
            names = " ".join(n for _, n in moved[prefix])
            new_lines.append("")
            new_lines.append(f"{prefix}_LANGUAGES = English Japanese")
            new_lines.append(f"{prefix}_LOCALIZED_RESOURCE_FILES += {names}")
    if not moved:
        return False
    en = os.path.join(d, "English.lproj")
    os.makedirs(en, exist_ok=True)
    for prefix, items in moved.items():
        for rel, name in items:
            dst = os.path.join(en, name)
            if os.path.exists(dst):
                print("  !! exists:", dst)
                continue
            subprocess.run(["git", "mv", os.path.join(d, rel), dst], check=True)
    out = "\n".join(new_lines)
    # drop an earlier "X_LANGUAGES = English" now superseded
    for prefix in moved:
        out = re.sub(rf"^{re.escape(prefix)}_LANGUAGES\s*=\s*English\s*$\n?", "", out, flags=re.M)
    open(mk, "w").write(out)
    print(mk, {p: [n for _, n in v] for p, v in moved.items()})
    return True


def main():
    for top in sys.argv[1:]:
        for root, dirs, files in os.walk(top):
            dirs[:] = [x for x in dirs if not x.endswith((".gorm", ".app", "obj", ".lproj"))]
            if "GNUmakefile" in files:
                process(os.path.join(root, "GNUmakefile"))


if __name__ == "__main__":
    main()
