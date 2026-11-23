"""apply.py <Locale.lua> <edits.py> [--dry]: apply text edits inside one language's block of an addon's Locale.lua.

edits.py defines EDITS = [(locale, old, new), ...] (exact source text, unique within that locale's block) and may
define REGEX = [(locale, pattern, replacement, expected_count), ...]. Every edit must match exactly once (a regex its
expected count), or nothing is written.
"""
import re
import sys

path, edits_path = sys.argv[1], sys.argv[2]
dry = "--dry" in sys.argv
src = open(path, encoding="utf-8", newline="").read()
NL = "\r\n" if "\r\n" in src else "\n"
scope = {}
exec(open(edits_path, encoding="utf-8").read(), scope)


def block(text, locale):
    if locale == "esMX":
        start = text.index(NL + "OWN.esMX = setmetatable({")
        end = text.index("}, { __index = OWN.esES })", start)
        return start, end
    start = text.index(NL + "    " + locale + " = {" + NL)
    end = text.index(NL + "    }," + NL, start)
    return start, end


problems = []
for locale, old, new in scope.get("EDITS", []):
    s, e = block(src, locale)
    part = src[s:e]
    n = part.count(old)
    if n != 1:
        problems.append(f"{locale}: {n} matches for {old[:70]!r}")
        continue
    src = src[:s] + part.replace(old, new) + src[e:]
for locale, key, value in scope.get("SET", []):
    s, e = block(src, locale)
    part = src[s:e]
    pattern = re.compile(r'(\n        ' + re.escape(key) + r' = )"(?:[^"\\\r\n]|\\.)*"')
    found = pattern.findall(part)
    if len(found) != 1:
        problems.append(f"{locale}: {len(found)} lines for key {key}")
        continue
    part = pattern.sub(lambda m: m.group(1) + '"' + value + '"', part)
    src = src[:s] + part + src[e:]
for locale, pattern, repl, expected in scope.get("REGEX", []):
    s, e = block(src, locale)
    part, n = re.subn(pattern, repl, src[s:e])
    if n != expected:
        problems.append(f"{locale}: regex {pattern!r} matched {n}, expected {expected}")
        continue
    src = src[:s] + part + src[e:]
if problems:
    print("NOT WRITTEN:\n  " + "\n  ".join(problems))
    sys.exit(1)
n = len(scope.get("EDITS", [])) + len(scope.get("SET", [])) + len(scope.get("REGEX", []))
if dry:
    print(f"dry run: {n} edits would apply")
else:
    open(path, "w", encoding="utf-8", newline="").write(src)
    print(f"written: {n} edits")
