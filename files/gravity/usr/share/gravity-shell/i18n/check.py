#!/usr/bin/env python3
"""Lists the text in the shell that a language file is missing, and what it has that the
shell no longer uses.

    i18n/check.py nl          # missing and unused in i18n/nl.json
    i18n/check.py nl --add    # also adds the missing ones to it, with "" to fill in

Text is found in I18n.tr("...") and I18n.trn("...", "...", n) calls, including both sides
of a condition (I18n.tr(on ? "On" : "Off")). An empty translation counts as missing and
shows the English.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CALL = re.compile(r"\bI18n\.trn?\(")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')


def first_args(src: str, start: int, count: int) -> str:
    """The text of the first `count` arguments of the call opening at `start`."""
    depth, i, args = 0, start, 0
    while i < len(src):
        c = src[i]
        if c == '"':
            i = src.index('"', i + 1) if src[i + 1] != '"' else i + 1
            while src[i - 1] == "\\" and src[i - 2] != "\\":
                i = src.index('"', i + 1)
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return src[start:i]
            depth -= 1
        elif c == "," and depth == 0:
            args += 1
            if args == count:
                return src[start:i]
        i += 1
    return src[start:]


def used() -> dict:
    found = {}
    for path in sorted(ROOT.rglob("*.qml")):
        src = path.read_text()
        for m in CALL.finditer(src):
            plural = m.group(0).endswith("trn(")
            args = first_args(src, m.end(), 2 if plural else 1)
            # Strings compared against (=== "x") are conditions, not text.
            args = re.sub(r'[!=]==\s*"(?:[^"\\]|\\.)*"', "", args)
            for s in STRING.findall(args):
                text = json.loads(f'"{s}"')
                found.setdefault(text, f"{path.relative_to(ROOT)}:{src.count(chr(10), 0, m.start()) + 1}")
    return found


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 2
    code = sys.argv[1]
    file = ROOT / "i18n" / f"{code}.json"
    table = json.loads(file.read_text()) if file.exists() else {}
    strings = used()
    missing = [s for s in strings if not table.get(s)]
    unused = [s for s in table if s not in strings]
    for s in missing:
        print(f"missing  {strings[s]}  {s!r}")
    for s in unused:
        print(f"unused   {s!r}")
    print(f"{len(strings) - len(missing)} of {len(strings)} translated, {len(unused)} unused")
    if "--add" in sys.argv[2:] and missing:
        table.update({s: "" for s in missing})
        file.write_text(json.dumps(table, ensure_ascii=False, indent=2) + "\n")
        print(f"added {len(missing)} to {file.relative_to(ROOT)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
