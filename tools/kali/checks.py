"""The offline checks the addons' runners share: their Lua loaded on a fake game, and their code held against this
build's API documentation and Blizzard's own source, which kali/game.py reads. First written for KaLi Quest, in its
runner.

A runner configures it for its addon before calling anything (one addon per run, so module settings are enough):
    from kali import checks
    checks.configure(ADDONS=<the addon's folder of folders>, NEEDS_FILE="KaLiQuest/Data/Needs.lua",
                     ALLOWED_GLOBALS={...})
Needs lupa in tools/pylib: python -I -m pip install --target tools/pylib lupa

A runner is made of parts ("The parts of a run" below). Those every runner has are played here the same way for each
addon: its tests, its smoke, the shared code's checks and the labels'. A whole run of a runner can play its parts side
by side, each in a process of its own (side_by_side): it then takes its longest part's time, not their sum.
"""
import json
import re
import subprocess
import sys
import tempfile
import time
from functools import cache
from pathlib import Path

from kali import labels
from kali.game import (atlas_names, blizzard_enums, doc_event_names, doc_function_names, doc_method_names,
                       documented_enums, global_api_names, map_types, modified_click_defaults, secret_functions,
                       ui_source_names)
from kali.paths import ROOT, use_pylib

use_pylib()
sys.stdout.reconfigure(encoding="utf-8")
import lupa.lua51 as lupa  # noqa: E402

# Set by configure(): the folder holding the addon's folders (or a copy, for experiments), its needs list, and the
# globals it may write.
ADDONS = None
NEEDS_FILE = None
ALLOWED_GLOBALS = set()
# The fake game every runner starts from, and the shared code's own checks, played on each addon's copy.
FAKE = ROOT / "tools/lua/fakewow.lua"
SHARED_SMOKE = ROOT / "tools/lua/smoke_shared.lua"


def configure(**settings):
    """ADDONS, NEEDS_FILE, ALLOWED_GLOBALS, and ENGINE_METHODS to add to; --addons <dir> on the command line runs on a
    copy instead (the addon folders are linked into the game)."""
    extra = settings.pop("ENGINE_METHODS", set())
    globals().update(settings)
    globals()["ENGINE_METHODS"] = ENGINE_METHODS | set(extra)
    if "--addons" in sys.argv:
        globals()["ADDONS"] = Path(sys.argv[sys.argv.index("--addons") + 1]).resolve()


LUA_BASE = {
    "assert", "collectgarbage", "error", "getmetatable", "ipairs", "loadstring", "next", "pairs", "pcall", "print",
    "rawequal", "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall",
}
LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
}
STRING_METHODS = {"byte", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper"}
# Methods of the game's own frames that Blizzard's Lua calls but neither the docs nor its Lua define.
ENGINE_METHODS = {"SetQuestLogSpecialItem", "SetQuestPartyProgress", "SetTag"}
TOC_FIELDS = ("Interface", "Title", "Notes", "Author", "Version", "Category", "X-License", "X-Website")
# Files a package may hold beside the TOC's own list and its icon. The game reads Bindings.xml by name.
PACKAGE_EXTRAS = {"Bindings.xml", "LICENSE", "README.md", "CHANGELOG.md"}

# Each global a file writes that isn't allowed goes in KALI_LEAKS, which the runner reports.
LOADER = r"""
KALI_LEAKS = {}
return function(path, source, addonName, ns, allowed)
    -- The addon the game blames for what it blocks (the fake's F.Blocked): the first loaded, the one under test.
    FakeWoW.blame = FakeWoW.blame or addonName
    local chunk, err = loadstring(source, "@" .. path)
    if not chunk then error(err, 0) end
    local env = setmetatable({}, {
        __index = _G,
        __newindex = function(_, key, value)
            if not allowed[key] then KALI_LEAKS[#KALI_LEAKS + 1] = path .. ": " .. tostring(key) end
            rawset(_G, key, value)
        end,
    })
    setfenv(chunk, env)
    chunk(addonName, ns)
end
"""


def rel(path):
    return str(path.relative_to(ADDONS.parent)).replace("\\", "/")


def toc_files(addon):
    files = []
    for line in (ADDONS / addon / f"{addon}.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(ADDONS / addon / line.replace("\\", "/"))
    return files


def fake_from_build(lua):
    """Gives the fake, once loaded, this build's own answers where its files hold them."""
    fake = lua.globals().FakeWoW
    fake.MODIFIED_CLICKS = lua.table_from(modified_click_defaults())
    fake.MAP_TYPES = lua.table_from(map_types())


def runtime():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(FAKE.read_text(encoding="utf-8"))
    fake_from_build(lua)
    loader = lua.execute(LOADER)
    allowed = lua.table_from({name: True for name in ALLOWED_GLOBALS})

    def load_addon(addon, namespace=None):
        ns = namespace if namespace is not None else lua.table()
        for path in toc_files(addon):
            loader(rel(path), path.read_text(encoding="utf-8"), addon, ns, allowed)
        return ns

    return lua, load_addon


def documented_functions(called_by_blizzard):
    # Some, such as C_Scenario.GetInfo, are missing from the docs but called by Blizzard's own code.
    return doc_function_names() | called_by_blizzard


def unknown_api_calls(sources, called_by_blizzard):
    known = documented_functions(called_by_blizzard)
    unknown = []
    for path in sources:
        for match in re.finditer(r"\b(C_\w+)\.(\w+)", path.read_text(encoding="utf-8")):
            name = f"{match.group(1)}.{match.group(2)}"
            if name not in known:
                unknown.append(f"{rel(path)}: {name}")
    return sorted(set(unknown)), len(known)


LONG_BRACKET = re.compile(r"\[(=*)\[")


def strip_lua(text, strings=None):
    """The code without comments, and with every string literal emptied. Given a list, it collects the literals
    instead, each one's place in the code holding its index in the list."""
    out, i, n = [], 0, len(text)

    def literal(content):
        if strings is None:
            return '""'
        strings.append(content)
        return f'"{len(strings) - 1}"'

    while i < n:
        if text.startswith("--", i):
            long = LONG_BRACKET.match(text, i + 2)
            if long:
                end = text.find("]" + long.group(1) + "]", i)
                i = n if end < 0 else end + len(long.group(1)) + 2
            else:
                end = text.find("\n", i)
                i = n if end < 0 else end
            continue
        c = text[i]
        if c == "[":
            long = LONG_BRACKET.match(text, i)
            if long:
                end = text.find("]" + long.group(1) + "]", i)
                start = i + len(long.group(0))
                i = n if end < 0 else end + len(long.group(1)) + 2
                out.append(literal(text[start:end if end >= 0 else n]))
                continue
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            out.append(literal(text[i + 1:j]))
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def local_names(code):
    """Every name the file declares as a local, a parameter or a loop variable. File-wide, which is enough here."""
    names = set(re.findall(r"\blocal\s+function\s+(\w+)", code))
    groups = re.findall(r"\blocal\s+([\w\s,]+?)\s*(?:=|\n)", code)
    groups += re.findall(r"\bfunction\b[^(\n]*\(([^)]*)\)", code)
    groups += re.findall(r"\bfor\s+([\w\s,]+?)\s+in\b", code)
    groups += re.findall(r"\bfor\s+(\w+)\s*=", code)
    for group in groups:
        names.update(part.strip() for part in group.split(",") if part.strip() and part.strip() != "...")
    return names


def known_globals(defined_by_blizzard):
    return set(LUA_BASE) | defined_by_blizzard | global_api_names()


def unknown_global_calls(sources, defined_by_blizzard):
    known = known_globals(defined_by_blizzard)
    # Globals the addons define for the game to call, such as key bindings and the addon compartment.
    for path in sources:
        known.update(name for name in re.findall(r"^function\s+(\w+)\s*\(", path.read_text(encoding="utf-8"), re.M) if name in ALLOWED_GLOBALS)
    unknown = []
    for path in sources:
        code = strip_lua(path.read_text(encoding="utf-8"))
        locals_ = local_names(code)
        for name in re.findall(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(", code):
            if name not in LUA_KEYWORDS and name not in locals_ and name not in known:
                unknown.append(f"{rel(path)}: {name}")
    return sorted(set(unknown))


def unknown_method_calls(sources, defined_by_blizzard):
    known = set(STRING_METHODS) | ENGINE_METHODS | defined_by_blizzard | doc_method_names()
    codes = {path: strip_lua(path.read_text(encoding="utf-8")) for path in sources}
    # The addons' own: methods, functions kept in fields, and fields given a function by name.
    for code in codes.values():
        known.update(re.findall(r"function\s+[\w.]+[:.](\w+)\s*\(", code))
        known.update(re.findall(r"\b(\w+)\s*=\s*function", code))
        known.update(re.findall(r"[.](\w+)\s*=\s*[\w.]+\s*$", code, re.M))
    unknown = []
    for path, code in codes.items():
        for name in re.findall(r":(\w+)\s*\(", code):
            if name not in known:
                unknown.append(f"{rel(path)}: {name}")
    return sorted(set(unknown))


def addon_enums(sources):
    """The Enum tables the addons name, with the members they name: { enum: { member } }."""
    used = {}
    for path in sources:
        code = strip_lua(path.read_text(encoding="utf-8"))
        for enum, member in re.findall(r"\bEnum\.(\w+)(?:\.(\w+))?", code):
            used.setdefault(enum, set())
            if member:
                used[enum].add(member)
    return used


def enum_problems(used):
    """Each Enum and member the addons name is in this build's docs, or read by Blizzard's own Lua. A name in neither
    is one the game may not have, and reads as nil."""
    documented, read_by_blizzard = documented_enums(), blizzard_enums()
    problems = []
    for enum, members in sorted(used.items()):
        blizzard = read_by_blizzard.get(enum)
        if enum not in documented and blizzard is None:
            problems.append(f"enum not in this build's docs nor Blizzard's code: Enum.{enum}")
            continue
        for m in sorted(members):
            if m not in documented.get(enum, {}) and m not in (blizzard or ()):
                problems.append(f"enum member not in this build's docs nor Blizzard's code: Enum.{enum}.{m}")
    return problems


# A value compared with itself, the usual test for nan: the game's Lua compares nan as equal to itself, so it never
# holds there (ns.Finite does it right).
SELF_COMPARE = re.compile(r"(?<![\w.:\]])([A-Za-z_][\w.]*(?:\[[^\]\n]*\])*)\s*(?:~=|==)\s*\1(?![\w.\[(:])")


def self_compare_problems(sources):
    problems = []
    for path in sources:
        code = strip_lua(path.read_text(encoding="utf-8"))
        for m in SELF_COMPARE.finditer(code):
            line = code.count("\n", 0, m.start()) + 1
            problems.append(f"nan: {rel(path)}:{line}: {m.group(0)} compares a value with itself, which the game's Lua "
                            "doesn't do for nan: use ns.Finite")
    return problems


# The game may hide some functions' results from addons (game.secret_functions). Secrecy that never touches the
# player's own unit: "when the unit isn't player-controlled or in the party/raid" (SecretPredicatesDocumentation.lua).
NOT_THE_PLAYER = {"SecretWhenUnitIdentityRestricted", "SecretWhenUnitNameIdentityRestricted"}
# What may stand just before such a call: the shared code's guard, around the call or around ns.Call's.
GUARDED = re.compile(r"\bns\.Plain\(\s*(?:ns\.Call\(\s*)?$")


def secret_problems(sources):
    """Every call of a function whose result the game may hide reads it through ns.Plain, which gives nil for a hidden
    value: ns.Plain(UnitGUID(unit)), or ns.Plain(ns.Call(UnitGUID, unit)). A unit's identity asked of "player", by
    that very word, needs none: UnitName("player"), ns.Call(UnitSex, "player"). Returns the problems and how many such
    calls it looked at."""
    functions = secret_functions()
    problems, looked = [], 0
    for path in sources:
        strings = []
        code = strip_lua(path.read_text(encoding="utf-8"), strings)
        for m in re.finditer(r"(?<![\w.:])((?:C_\w+\.)?[A-Za-z_]\w*)\b(?!\s*=(?!=))", code):
            kinds = functions.get(m.group(1))
            if not kinds:
                continue
            looked += 1
            before, after = code[:m.start()], code[m.end():]
            # The unit asked: the call's first argument, or ns.Call's second.
            through_call = re.search(r"\bns\.Call\(\s*$", before)
            first = re.match(r'\s*,\s*"(\d+)"\s*[,)]' if through_call else r'\s*\(\s*"(\d+)"\s*[,)]', after)
            of_player = first is not None and strings[int(first.group(1))] == "player"
            if (of_player and kinds <= NOT_THE_PLAYER) or GUARDED.search(before):
                continue
            line = code.count("\n", 0, m.start()) + 1
            problems.append(f"secret: {rel(path)}:{line}: {m.group(1)} may answer with a secret value "
                            f"({', '.join(sorted(kinds))}): read it through ns.Plain")
    return problems, looked


def needs(sources, documented, defined_in, templates_in, fonts_in):
    """What the shipped addon takes from the game: the globals it names, each with the Blizzard addons that define
    it or "" for the game itself, fonts included, the events, atlases and templates its strings name, the CVars it
    reads or sets, and the game strings it reads through ns.G."""
    global_api = global_api_names()
    events = doc_event_names()
    atlases = atlas_names()
    found = {"globals": {}, "events": set(), "atlases": set(), "templates": {}, "cvars": set(), "strings": set()}
    for path in sources:
        strings = []
        code = strip_lua(path.read_text(encoding="utf-8"), strings)
        locals_ = local_names(code)
        for name in re.findall(r"\b(C_\w+\.\w+)", code):
            if name in documented:
                found["globals"][name] = ""
        # A name followed by a single "=" is a table's field or an assignment, not something read from the game.
        for name in re.findall(r"(?<![\w.:])([A-Za-z_]\w*)\b(?!\s*=(?!=))", code):
            if name in LUA_KEYWORDS or name in LUA_BASE or name in locals_ or name in ALLOWED_GLOBALS or name.startswith("C_"):
                continue
            if name in global_api:
                found["globals"][name] = ""
            elif name in defined_in and name not in found["globals"]:
                found["globals"][name] = ",".join(sorted(defined_in[name]))
        for s in strings:
            if s in events:
                found["events"].add(s)
            if s in templates_in:
                found["templates"][s] = ",".join(sorted(templates_in[s]))
            if s in fonts_in:
                found["globals"][s] = ",".join(sorted(fonts_in[s]))
            if ("-" in s or "_" in s) and s.lower() in atlases:
                found["atlases"].add(s)
            found["atlases"].update(a for a in re.findall(r"\|A:([\w-]+):", s) if a.lower() in atlases)
        for index in re.findall(r'\b(?:GetCVar|GetCVarBool|SetCVar|C_CVar\.\w+)\(\s*"(\d+)"', code):
            found["cvars"].add(strings[int(index)])
        # ns.G("NAME", fallback), or a table's name = "NAME", fallback = ... passed to it. Not a name made at run time,
        # ns.G("RAID_TARGET_" .. n): the game has no string by its first part alone.
        for index in re.findall(r'\bns\.G\(\s*"(\d+)"(?!\s*\.\.)|\bname\s*=\s*"(\d+)"\s*,\s*fallback\s*=', code):
            found["strings"].add(strings[int(index[0] or index[1])])
    return found


def needs_lua(found):
    lines = [
        "-- Made from the addon's own code by its runner's --write-needs (tools/kali/checks.py), whose checks fail a stale",
        "-- copy: what the addon takes from the game, for its API check at login (SelfCheck).",
        "local _, ns = ...",
        "",
        "-- A global or a template names the Blizzard addons that define it, or \"\" for the game itself.",
        "ns.NEEDS = {",
    ]
    for key in ("globals", "events", "atlases", "templates", "cvars", "strings"):
        value = found[key]
        lines.append(f"    {key} = {{")
        if isinstance(value, dict):
            lines += [f'        ["{name}"] = "{value[name]}",' for name in sorted(value)]
        else:
            lines += [f'        "{name}",' for name in sorted(value)]
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def shared_smoke(lua, addon):
    """The shared code's checks on this addon's copy, in the state its smoke session left: a list of failures."""
    lua.globals().KALI_ADDON = addon
    return list(lua.execute(SHARED_SMOKE.read_text(encoding="utf-8")).values())


def icon_problem(path):
    if not path.exists():
        return "the file is missing"
    if path.suffix.lower() != ".tga":
        return None
    head = path.read_bytes()[:18]
    if len(head) < 18 or head[2] not in (2, 10) or head[16] != 32:
        return "not a 32-bit true-colour TGA"
    width, height = head[12] | head[13] << 8, head[14] | head[15] << 8
    if width & (width - 1) or height & (height - 1) or not width or not height:
        return f"{width} by {height}, not powers of two"
    return None


def media_path(folder, inside):
    """A file the game finds from a path inside the addon: with no extension, it tries .blp, then .tga."""
    path = folder / inside
    if path.suffix:
        return path
    return next((path.with_suffix(s) for s in (".blp", ".tga") if path.with_suffix(s).exists()), path.with_suffix(".tga"))


def own_paths(addon, files):
    """The paths into the addon's own folder its Lua and XML name (Interface\\AddOns\\<addon>\\...), with who names them."""
    sep = r"(?:\\{1,2}|/)"
    pattern = re.compile(rf"Interface{sep}AddOns{sep}{re.escape(addon)}{sep}([\w.\\/-]+)", re.I)
    found = {}
    for path in files:
        if path.suffix.lower() in (".lua", ".xml") and path.exists():
            for m in pattern.finditer(path.read_text(encoding="utf-8")):
                inside = re.sub(r"[\\/]+", "/", m.group(1)).strip("/")
                if inside:
                    found.setdefault(inside, path)
    return found


def package_problems(addon):
    folder = ADDONS / addon
    toc = (folder / f"{addon}.toc").read_text(encoding="utf-8")
    fields = dict(re.findall(r"^## ([\w-]+):[ \t]*(.*?)\s*$", toc, re.M))
    problems = [f"package: the TOC has no ## {name}" for name in TOC_FIELDS if not fields.get(name)]
    listed = toc_files(addon)
    problems += [f"package: the TOC lists {rel(p)}, which is missing" for p in listed if not p.exists()]
    shipped = {folder / f"{addon}.toc", *listed, *(folder / name for name in PACKAGE_EXTRAS)}
    icon = fields.get("IconTexture")
    prefix = f"interface\\addons\\{addon.lower()}\\"
    if icon and icon.lower().startswith(prefix):
        path = media_path(folder, icon[len(prefix):].replace("\\", "/"))
        shipped.add(path)
        problem = icon_problem(path)
        if problem:
            problems.append(f"package: the icon {rel(path)}: {problem}")
    elif not icon and not fields.get("IconAtlas"):
        problems.append("package: the TOC names no icon")
    # The minimap button's icon and the like: a file the code names inside the addon is shipped, and must be there.
    for inside, source in sorted(own_paths(addon, listed).items()):
        path = media_path(folder, inside)
        shipped.add(path)
        if not path.exists():
            problems.append(f"package: {rel(source)} names {inside}, which isn't in the addon")
    known = {str(p).lower() for p in shipped}
    files = [p for p in folder.rglob("*") if p.is_file()]
    problems += [f"package: {rel(p)} isn't in the TOC or the package's extras" for p in files if str(p).lower() not in known]
    return problems, len(files)


# ---------- The parts of a run ----------
# A runner's whole run plays its parts in turn, KaLi HUD's side by side (side_by_side); the shared code's checks and
# the labels' then come after the smoke, on the game it left, not after a login alone. --only <part>[,<part>...] runs
# those alone, after the compile; --at <what> narrows the part it's for: the smoke to its block whose check says that
# text (smoke_session), the static checks to the one it names (static_check_of). What tools/breaks.py runs each
# deliberate break against: a second or two, never the whole run (Ikar 2026-11-18: "Link each break with test on
# interest, and run only those").


def asked():
    """The parts asked on the command line (None: all of them) and the narrowing (--at: a number is a block's line)."""
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else None
    at = sys.argv[sys.argv.index("--at") + 1] if "--at" in sys.argv else None
    return only, (int(at) if at and at.isdigit() else at)


class Run:
    """A run's problems, part by part, and its end: ALL PASS, or the problems once each and FAIL (exit 1).
    parts: the runner's own, in a whole run's order; words(name): whether a name that's no part is still one the
    runner takes (KaLi HUD's: a word its scenarios' names hold)."""

    def __init__(self, parts, words=None):
        self.only, self.at = asked()
        # --report <file>: this run is one of a whole run's processes (side_by_side), and its problems go there.
        self.report = Path(sys.argv[sys.argv.index("--report") + 1]) if "--report" in sys.argv else None
        self.problems = []
        for name in self.only or []:
            if name not in parts and not (words and words(name)):
                self.problems.append(f"parts: none named {name} (the parts: {', '.join(parts)})")

    def wants(self, name):
        return self.only is None or name in self.only

    def part(self, name, run):
        """A part, if asked: run() gives its problems."""
        if self.wants(name):
            started = time.time()
            self.problems.extend(run())
            print(f"[{name}: {time.time() - started:.1f} s]", flush=True)

    def end(self):
        problems = list(dict.fromkeys(self.problems))
        if self.report:  # one process of a whole run: the whole run says them
            self.report.write_text(json.dumps(problems), encoding="utf-8")
            return
        print()
        if problems:
            print("\n".join(problems))
            print(f"\nFAIL: {len(problems)} problem(s)")
            sys.exit(1)
        print("ALL PASS")


def side_by_side(runner, groups):
    """A whole run's parts side by side: the runner started again for each group of its arguments (["--only",
    "smoke"], ...), with this run's own, all at once, each in a process of its own. The run then takes its longest
    group's time, not their sum. Gives each group's (what it said, its problems), in the groups' order; one that ended
    without giving its problems (it raised: what it said shows why) gives that as its problem."""
    with tempfile.TemporaryDirectory() as folder:
        running = []
        for k, group in enumerate(groups):
            report = Path(folder) / f"{k}.json"
            out = tempfile.TemporaryFile()
            command = [sys.executable, "-I", str(runner), *sys.argv[1:], *group, "--report", str(report)]
            running.append((group, subprocess.Popen(command, stdout=out, stderr=subprocess.STDOUT), out, report))
        results = []
        for group, process, out, report in running:
            process.wait()
            out.seek(0)
            said = out.read().decode("utf-8", errors="replace").replace("\r\n", "\n").rstrip()
            out.close()
            try:
                problems = json.loads(report.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                problems = [f"{' '.join(group)}: its process ended (code {process.returncode}) without its problems"]
            results.append((said, problems))
    return results


# What the compiler said of each file as it stood ((path, its time and size): None for nothing), and the runtime it
# compiles in: a worker's runs compile again only the file a break was planted in.
COMPILED = {}
COMPILER = []


def compile_problems(say=True):
    """Every .lua file of the addon's folders compiles: (problems, the files). say: print how many (a whole run's
    process leaves it to the whole run)."""
    if not COMPILER:
        COMPILER.append(lupa.LuaRuntime(unpack_returned_tuples=True))
    sources, problems = sorted(ADDONS.rglob("*.lua")), []
    for path in sources:
        stat = path.stat()
        stamp = (path, stat.st_mtime_ns, stat.st_size)
        if stamp not in COMPILED:
            result = COMPILER[0].globals().loadstring(path.read_text(encoding="utf-8"), "@" + rel(path))
            COMPILED[stamp] = result[1] if isinstance(result, tuple) and result[1] else None
        if COMPILED[stamp]:
            problems.append(f"compile: {COMPILED[stamp]}")
    if say:
        print(f"compile: {len(sources)} files")
    return problems, sources


# The static checks' names, by the start of what each says (the rest say their name first: "needs: ...").
STATIC_SAYS = (("api not in", "api"), ("global function not in", "globals"), ("method not in", "methods"),
               ("enum", "enums"))


def static_check_of(problem):
    """The static check that found a problem, by what it says: a link's --at for the static part."""
    for start, name in STATIC_SAYS:
        if problem.startswith(start):
            return name
    return problem.split(":", 1)[0]


class StaticChecks(list):
    """[(name, check)], and found(): what the needs list holds."""


def static_checks(addon, sources, shipped, needs_path, runner):
    """The family's static checks of an addon, [(name, check)]: what its code names against this build's API docs and
    Blizzard's own code, its enums, the needs list its code gives (--write-needs writes it; runner: the command that
    does), its package, nan, the secret values. A check prints its line and gives its problems. The list's found()
    gives what the needs list holds, worked out once."""
    made = {}

    def found():
        if "found" not in made:
            called, _, _, defined_in, templates_in, fonts_in = ui_source_names()
            made["found"] = needs(shipped, documented_functions(called), defined_in, templates_in, fonts_in)
        return made["found"]

    def api():
        unknown, known = unknown_api_calls(sources, ui_source_names()[0])
        print(f"api: {known} documented C_ functions, {len(unknown)} unknown names used")
        return [f"api not in this build's docs: {u}" for u in unknown]

    def globals_():
        unknown = unknown_global_calls(sources, ui_source_names()[1])
        print(f"globals: {len(unknown)} unknown global functions called")
        return [f"global function not in the game: {u}" for u in unknown]

    def methods():
        unknown = unknown_method_calls(sources, ui_source_names()[2])
        print(f"methods: {len(unknown)} unknown method names called")
        return [f"method not in the game: {u}" for u in unknown]

    def enums():
        used = addon_enums(sources)
        problems = enum_problems(used)
        print(f"enums: {len(used)} named, {len(problems)} not in this build's docs nor Blizzard's code")
        return problems

    def needs_():
        expected = needs_lua(found())
        problems = []
        if "--write-needs" in sys.argv:
            needs_path.parent.mkdir(parents=True, exist_ok=True)
            needs_path.write_text(expected, encoding="utf-8", newline="\n")
        elif not needs_path.exists() or needs_path.read_text(encoding="utf-8") != expected:
            problems.append(f"needs: {rel(needs_path)} is out of date: run {runner} --write-needs")
        f = found()
        print(f"needs: {len(f['globals'])} globals, {len(f['events'])} events, {len(f['atlases'])} atlases, "
              f"{len(f['templates'])} templates, {len(f['cvars'])} CVars, {len(f['strings'])} strings")
        return problems

    def package():
        problems, count = package_problems(addon)
        print(f"package: {count} files, {len(problems)} problems")
        return problems

    def nan():
        problems = self_compare_problems(shipped)
        print(f"nan: {len(problems)} values compared with themselves in the shipped addon")
        return problems

    def secret():
        problems, hidden = secret_problems(shipped)
        print(f"secret: {hidden} calls whose result the game may hide, {len(problems)} not read through ns.Plain")
        return problems

    out = StaticChecks([("api", api), ("globals", globals_), ("methods", methods), ("enums", enums),
                        ("needs", needs_), ("package", package), ("nan", nan), ("secret", secret)])
    out.found = found
    return out


def run_static(checks_, at=None):
    """The static checks [(name, check)], or only the one `at` names."""
    names = [name for name, _ in checks_]
    if at is not None and at not in names:
        return [f"static: no check named {at} (the checks: {', '.join(names)})"]
    problems = []
    for name, check in checks_:
        if at is None or name == at:
            problems += check()
    return problems


def leaks(lua, addon=None):
    """The globals the addons' files wrote that they may not (the loader's KALI_LEAKS): a missing "local". With an
    addon's name, its own files' alone (a test addon stands in for the game's strings, HEADER_COLON)."""
    found = sorted(set(lua.globals().KALI_LEAKS.values()))
    return [f"global written: {leak}" for leak in found if not addon or leak.startswith(f"addon/{addon}/")]


def smoke_session(path, at=None, stamp=None):
    """A smoke's session (the file at `path`, as it stood at `stamp`), whole; or, for a text one of its checks says
    (`at`), with only the block that holds that check: the session's blocks (smoke_layout) are scopes of their own, so
    one left out takes no name another needs, and what stands between the blocks is always run (a block the rest stands
    on says so after its `do`, and is never left out). Whether a block can stand without those before it is for who
    asks to know: tools/breaks.py tries each it runs, on the code as it is, before any break. A text no block holds,
    among what's always run: no block at all. `at` a number: the block that starts at that line, 0 none.
    Returns the source, and the lines of the blocks kept (none: an empty list); None for the whole session. A text no
    line of the session holds: LookupError (a link gone stale, which would otherwise run the whole session)."""
    stamp = stamp or path.stat().st_mtime_ns
    text, lines, blocks = smoke_layout(path, stamp)
    if at is None or at == "":
        return text, None
    kept = blocks_kept(path, at, stamp)
    out = list(lines)
    for start, _, _ in blocks:
        if start + 1 not in kept:
            out[start] = "if false then"
    return "\n".join(out), list(kept)


class LayoutError(ValueError):
    """A smoke whose blocks can't be told apart (smoke_layout)."""


@cache
def smoke_layout(path, stamp):
    """A smoke's text, its lines and its blocks [(first line, last line, their text)], 0-based, as the file stood at
    `stamp`. A block is a line `do` alone, its lines indented, to its first line at the margin, which is `end` alone.
    Anything else at the margin inside a block is a LayoutError: the block would end there unseen, its checks run
    with what stands between the blocks."""
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    blocks = []
    for start, line in enumerate(lines):
        if line != "do":
            continue
        end = next((j for j in range(start + 1, len(lines)) if lines[j][:1] not in ("", " ", "\t")), None)
        if end is None or lines[end] != "end":
            name = path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else path
            reached = f"line {end + 1}, {lines[end][:40]!r}," if end is not None else "the end of the file"
            raise LayoutError(f"{name}: the block at line {start + 1} reaches {reached} before its `end` alone at the "
                              "margin: indent every line of a block")
        blocks.append((start, end, "\n".join(lines[start:end + 1])))
    return text, lines, blocks


@cache
def blocks_kept(path, at, stamp=None):
    """The lines of the blocks a smoke's session keeps for `at` (smoke_session), as a tuple."""
    text, lines, blocks = smoke_layout(path, stamp or path.stat().st_mtime_ns)
    if isinstance(at, str):
        # what a check says often ends in what it found ("...: 3 for 2"): the longest start of the text that the
        # session's source holds, a score of letters at the least
        while len(at) > 20 and at not in text:
            at = at[:-1]
        if at not in text:
            raise LookupError(at)
    if isinstance(at, int) and at and all(start + 1 != at for start, _, _ in blocks):
        raise LookupError(f"no block starts at line {at}")
    # every block that says the text: two checks may say the same words; a text within one line of it
    return tuple(start + 1 for start, end, block in blocks
                 if start + 1 == at or isinstance(at, str) and at in block
                 and ("\n" not in at or any(at in line for line in lines[start:end + 1])))


def smoke_blocks(path):
    """The lines a smoke's blocks start at (smoke_session), 0 first for none of them."""
    return [0] + [start + 1 for start, _, _ in smoke_layout(path, path.stat().st_mtime_ns)[2]]


def smoke_said(failures, blocks):
    """The smoke part's line: whether it passed, and which of its blocks ran."""
    print(f"smoke: {'PASS' if not failures else 'FAIL'}"
          + (f" (the block at line {', '.join(map(str, blocks))} alone)" if blocks
             else " (no block, what stands between them)" if blocks is not None else ""))


# Each failure the session keeps, and an error that gets out of it, said with the block it came from and the line of
# the session's own that was running (its main chunk's: the check, or the call that led to it). A check whose words
# are made as it runs ("<name> holds on the fake: ...") is found so, though no line of the session says them:
# tools/breaks.py --link names the block by that line's text, which stays with its check when a block is cut up. Its
# `failures` table is watched, and each block's first and last line say where the session is.
FAILURES = re.compile(r"^local failures = \{\}$", re.M)
WATCH = ("local failures = {}; KALI_WHERE, KALI_LINES, KALI_FAILURES = {}, {}, failures; setmetatable(failures, { "
         "__newindex = function(t, k, v) rawset(t, k, v); KALI_WHERE[k] = KALI_BLOCK or 0; KALI_LINES[k] = KALI_LINE() "
         "end })")
# The session (KALI_SESSION) run as a function, which KALI_LINE finds on the stack; an error that gets out of it
# caught where it was raised, the line running then with it.
RUN = """
local chunk, problem = loadstring(KALI_SESSION, "<python>")
if not chunk then
    return false, problem
end
function KALI_LINE()
    for level = 2, 250 do
        local info = debug.getinfo(level, "fl")
        if not info then
            return nil
        end
        if info.func == chunk then
            return info.currentline
        end
    end
end
local line
local ok, result = xpcall(chunk, function(message)
    line = KALI_LINE()
    return message
end)
return ok, result, line
"""
FIRST_FROM = re.compile(r"^smoke: its first failure from (?:the block at line (\d+)|(what stands between the blocks))"
                        r"(?:, at line (\d+))?", re.M)


def smoke_run(lua, path, at=None):
    """A smoke's session (smoke_session) in a game made for it: (its failures, the blocks kept, where its first
    failure came from: (the line of its block, 0 for what stands between them; the session's line that was running,
    None when unknown), None with no failure). A Lua error that gets out of the session is one more failure, after
    those it kept."""
    stamp = path.stat().st_mtime_ns
    session, blocks = smoke_session(path, at, stamp)
    lines = session.split("\n")
    for start, end, _ in smoke_layout(path, stamp)[2]:
        if lines[start] == "do":  # a block kept: smoke_session turns the others off
            lines[start] = f"do KALI_BLOCK = {start + 1}"
            lines[end] = "KALI_BLOCK = 0 " + lines[end]
    g = lua.globals()
    g.KALI_SESSION = FAILURES.sub(WATCH, "\n".join(lines), count=1)
    try:
        got = lua.execute(RUN)
    finally:
        g.KALI_SESSION = None
    got = got if isinstance(got, tuple) else (got,)
    ok, result, line = got + (None,) * (3 - len(got))
    if ok:
        failures = list(result.values())
    else:
        kept = g.KALI_FAILURES
        failures = (list(kept.values()) if kept else []) + [f"error: {str(result).splitlines()[0]}"]
        if g.KALI_WHERE is not None:
            g.KALI_WHERE[len(failures)] = g.KALI_BLOCK or 0
            g.KALI_LINES[len(failures)] = line
    first = None
    if failures and g.KALI_WHERE is not None and g.KALI_WHERE[1] is not None:
        line = g.KALI_LINES[1]
        first = (int(g.KALI_WHERE[1]), int(line) if line is not None else None)
    return failures, blocks, first


def smoke_first(first):
    """The line that says where the first failure came from (smoke_run): read back by FIRST_FROM."""
    if first is not None:
        block, line = first
        print("smoke: its first failure from " + (f"the block at line {block}" if block
                                                  else "what stands between the blocks")
              + (f", at line {line}" if line else ""))


# ---------- The parts every runner has ----------
# Played the same way for each addon, in the runner's game (runtime: runtime() above, or the runner's own, which adds
# its part of the fake). An addon's folders and globals follow its name: <addon>_Tests holds its tests, which make
# <addon>Tests; <addon>_Probe, when there is one, its probe; <addon>Dev holds its namespace for the tests.

# A login as the game gives it, for a part played after a login alone.
LOGIN = """
FakeWoW.Fire("ADDON_LOADED", "{addon}")
FakeWoW.Fire("PLAYER_LOGIN")
FakeWoW.Fire("PLAYER_ENTERING_WORLD", true, false)
FakeWoW.RunTimers()
"""


def logged_in(runtime, addon):
    """A game started for a part alone: the addon loaded, and a login."""
    lua, load_addon = runtime()
    load_addon(addon)
    lua.execute(LOGIN.format(addon=addon))
    return lua


def with_probe(runtime, addon):
    """A game with the addon loaded, then its probe when it has one: (the Lua state, its loader)."""
    lua, load_addon = runtime()
    load_addon(addon)
    if (ADDONS / f"{addon}_Probe").exists():
        load_addon(f"{addon}_Probe")
    return lua, load_addon


def tests_part(runtime, addon):
    """The addon's tests, the same as in game (/kq test, /kr test, /kh test): their report, a problem when one fails,
    and the globals the addon's own files wrote."""
    lua, load_addon = runtime()
    load_addon(addon)
    load_addon(f"{addon}_Tests")
    report = lua.eval(f"{addon}Tests.Run()")
    print(report.text)
    return ([f"tests: {report.summary}"] if report.failed > 0 else []) + leaks(lua, addon)


def smoke_part(runtime, addon, path, at=None):
    """The smoke's session (smoke_run), or its block for `at`, in a game with the addon and its probe: (the Lua state,
    its loader, the problems, the blocks kept: None for the whole session, which the runner follows with after_smoke
    and its own checks of the game the session left)."""
    lua, load_addon = with_probe(runtime, addon)
    try:
        failures, blocks, first = smoke_run(lua, path, at)
    except LookupError as missing:
        return lua, load_addon, [f"smoke: --at: no line of the session says {missing}"], []
    except LayoutError as wrong:
        return lua, load_addon, [f"smoke: {wrong}"], []
    smoke_said(failures, blocks)
    smoke_first(first)
    return lua, load_addon, [f"smoke: {f}" for f in failures], blocks


def label_problems(lua, addon, dialog):
    """The texts of the addon's dialog (its frame's global name) and of its options page, as the game `lua` shows
    them, against their room in every language (kali/labels.py): the misfits."""
    misfits, measured = labels.problems(lua, f"{addon}Dev", dialog)
    print(measured)
    return misfits


def after_smoke(lua, addon, dialog):
    """What every runner checks of the game a whole smoke session left: the shared code's checks, the labels, the
    globals the files wrote."""
    failures = shared_smoke(lua, addon)
    print(f"shared: {'PASS' if not failures else 'FAIL'}")
    return failures + label_problems(lua, addon, dialog) + leaks(lua)


def shared_part(runtime, addon):
    """The shared code's checks after a login alone: a break of the shared code in seconds."""
    lua = logged_in(runtime, addon)
    failures = shared_smoke(lua, addon)
    print(f"shared: {'PASS' if not failures else 'FAIL'}, after a login alone")
    return failures + leaks(lua)


def labels_part(runtime, addon, dialog, opens):
    """The labels' check after a login alone, the dialog and the options page opened first (opens: the Lua that does)."""
    lua = logged_in(runtime, addon)
    lua.execute(opens)
    return label_problems(lua, addon, dialog)


