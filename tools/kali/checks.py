"""The offline checks both addons' runners share: their Lua loaded on a fake game, and their code held against this
build's API documentation and Blizzard's own source. First written for KaLi Quest, in its runner.

A runner configures it for its addon before calling anything (one addon per run, so module settings are enough):
    from kali import checks
    checks.configure(ADDONS=<the addon's folder of folders>, NEEDS_FILE="KaLiQuest/Data/Needs.lua",
                     ALLOWED_GLOBALS={...})
Needs lupa in tools/pylib: python -I -m pip install --target tools/pylib lupa
"""
import csv
import re
import sys
from pathlib import Path

from kali.paths import REFERENCE, ROOT, use_pylib

use_pylib()
sys.stdout.reconfigure(encoding="utf-8")
import lupa.lua51 as lupa  # noqa: E402

# Set by configure(): the folder holding the addon's folders (or a copy, for experiments), its needs list, and the
# globals it may write.
ADDONS = None
NEEDS_FILE = None
ALLOWED_GLOBALS = set()
# The fake game every runner starts from.
FAKE = ROOT / "tools/lua/fakewow.lua"
API_DOCS = REFERENCE / "wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated"
UI_SOURCE = REFERENCE / "wow-ui-source/Interface"
GLOBAL_API = REFERENCE / "BlizzardInterfaceResources/Resources/GlobalAPI.lua"
DB2 = REFERENCE / "db2"


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
TOC_FIELDS = ("Interface", "Title", "Notes", "Author", "Version", "Category", "X-License")
# Files a package may hold beside the TOC's own list and its icon. The game reads Bindings.xml by name.
PACKAGE_EXTRAS = {"Bindings.xml", "LICENSE", "README.md", "CHANGELOG.md"}

LOADER = r"""
KQ_LEAKS = {}
return function(path, source, addonName, ns, allowed)
    local chunk, err = loadstring(source, "@" .. path)
    if not chunk then error(err, 0) end
    local env = setmetatable({}, {
        __index = _G,
        __newindex = function(_, key, value)
            if not allowed[key] then KQ_LEAKS[#KQ_LEAKS + 1] = path .. ": " .. tostring(key) end
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


def runtime():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(FAKE.read_text(encoding="utf-8"))
    loader = lua.execute(LOADER)
    allowed = lua.table_from({name: True for name in ALLOWED_GLOBALS})

    def load_addon(addon, namespace=None):
        ns = namespace if namespace is not None else lua.table()
        for path in toc_files(addon):
            loader(rel(path), path.read_text(encoding="utf-8"), addon, ns, allowed)
        return ns

    return lua, load_addon


def blizzard_addon(path):
    return path.relative_to(UI_SOURCE / "AddOns").parts[0]


def ui_source_names():
    """C_ functions Blizzard's own Lua calls, the global names it defines, the methods it defines, and which of its
    addons define each global, each template and each font, in one pass."""
    c_names, globals_, methods = set(), set(), set()
    defined_in, templates_in, fonts_in = {}, {}, {}
    for path in UI_SOURCE.rglob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        c_names.update(re.findall(r"\b(C_\w+\.\w+)\(", text))
        names = set(re.findall(r"^function\s+(\w+)\s*\(", text, re.M)) | set(re.findall(r"^(\w+)\s*=", text, re.M))
        globals_.update(names)
        for name in names:
            defined_in.setdefault(name, set()).add(blizzard_addon(path))
        methods.update(re.findall(r"function\s+[\w.]+[:.](\w+)\s*\(", text))
        methods.update(re.findall(r"^\s*(\w+)\s*=\s*function", text, re.M))
    for path in UI_SOURCE.rglob("*.xml"):
        text = path.read_text(encoding="utf-8", errors="replace")
        methods.update(re.findall(r'method="(\w+)"', text))
        # A named font is a global, as is a named frame unless it's virtual: a template.
        for tag in re.findall(r"<\w+\s[^>]*>", text):
            name = re.search(r'\bname="(\w+)"', tag)
            if name:
                if re.match(r"<Font(Family)?\s", tag):
                    target = fonts_in
                else:
                    target = templates_in if 'virtual="true"' in tag else defined_in
                target.setdefault(name.group(1), set()).add(blizzard_addon(path))
    return c_names, globals_, methods, defined_in, templates_in, fonts_in


def documented_functions(called_by_blizzard):
    names = set()
    for path in API_DOCS.glob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        namespace = re.search(r'Namespace = "(\w+)"', text)
        if not namespace:
            continue
        for fn in re.findall(r'Name = "(\w+)",\s*Type = "Function"', text):
            names.add(f"{namespace.group(1)}.{fn}")
    # Some, such as C_Scenario.GetInfo, are missing from the docs but called by Blizzard's own code.
    return names | called_by_blizzard


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
    names = set(LUA_BASE) | defined_by_blizzard
    names.update(re.findall(r'^\s*"(\w+)",', GLOBAL_API.read_text(encoding="utf-8"), re.M))
    return names


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
    known = set(STRING_METHODS) | ENGINE_METHODS | defined_by_blizzard
    for path in API_DOCS.glob("*.lua"):
        known.update(re.findall(r'Name = "(\w+)",\s*Type = "Function"', path.read_text(encoding="utf-8", errors="replace")))
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


def atlas_names():
    """Every atlas this build's tables name, in lower case, as the game matches them."""
    folder = max(DB2.iterdir())
    names = set()
    for file, column in (("UiTextureAtlasElement.csv", "Name"), ("UiTextureAtlasMember.csv", "CommittedName")):
        with open(folder / file, encoding="utf-8", newline="") as f:
            names.update(row[column].lower() for row in csv.DictReader(f))
    return names


def needs(sources, documented, defined_in, templates_in, fonts_in):
    """What the shipped addon takes from the game: the globals it names, each with the Blizzard addons that define
    it or "" for the game itself, fonts included, the events, atlases and templates its strings name, the CVars it
    reads or sets, and the game strings it reads through ns.G."""
    global_api = set(re.findall(r'^\s*"(\w+)",', GLOBAL_API.read_text(encoding="utf-8"), re.M))
    events = set()
    for path in API_DOCS.glob("*.lua"):
        events.update(re.findall(r'LiteralName = "(\w+)"', path.read_text(encoding="utf-8", errors="replace")))
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
        # ns.G("NAME", fallback), or a table's name = "NAME", fallback = ... passed to it.
        for index in re.findall(r'\bns\.G\(\s*"(\d+)"|\bname\s*=\s*"(\d+)"\s*,\s*fallback\s*=', code):
            found["strings"].add(strings[int(index[0] or index[1])])
    return found


def needs_lua(found):
    lines = [
        "-- Made from the addon's own code by tools/scripts/run_lua_tests.py --write-needs, whose checks fail a stale copy:",
        "-- what the addon takes from the game, for Core/SelfCheck.lua.",
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
        path = folder / icon[len(prefix):].replace("\\", "/")
        if not path.suffix:
            path = next((path.with_suffix(s) for s in (".blp", ".tga") if path.with_suffix(s).exists()), path.with_suffix(".tga"))
        shipped.add(path)
        problem = icon_problem(path)
        if problem:
            problems.append(f"package: the icon {rel(path)}: {problem}")
    elif not icon and not fields.get("IconAtlas"):
        problems.append("package: the TOC names no icon")
    known = {str(p).lower() for p in shipped}
    files = [p for p in folder.rglob("*") if p.is_file()]
    problems += [f"package: {rel(p)} isn't in the TOC or the package's extras" for p in files if str(p).lower() not in known]
    return problems, len(files)


