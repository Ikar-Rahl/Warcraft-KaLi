"""What this build's own files say, for the checks (kali/checks.py), the runners and the fake game: Blizzard's source,
its API documentation, the game's list of global functions and the build's tables, all in the reference folder
(kali/paths.py).

Each is read once a process (@cache): a run reads it once anyway, and a break's worker (tools/kali/worker.py), which
runs the checks again for each break, would otherwise read it all again each time. What takes long to read,
Blizzard's source and the API docs' lists, is kept on disk from one run to the next (kali/kept.py) while the files it
comes from and this file stay the same. The readers have this file to themselves: an edit of the checks keeps what
they read.
"""
import csv
import re
from functools import cache, wraps

from kali.kept import files, kept, stamps
from kali.paths import REFERENCE

API_DOCS = REFERENCE / "wow-ui-source/Interface/AddOns/Blizzard_APIDocumentationGenerated"
UI_SOURCE = REFERENCE / "wow-ui-source/Interface"
# Forever's key bindings and modified clicks, whose defaults the fake gives.
BINDINGS = UI_SOURCE / "AddOns/Blizzard_FrameXML/Bindings_Camelot.xml"
# Blizzard's names of the sound kits, its SOUNDKIT table.
SOUNDKITS = UI_SOURCE / "AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua"
GLOBAL_API = REFERENCE / "BlizzardInterfaceResources/Resources/GlobalAPI.lua"
DB2 = REFERENCE / "db2"


@cache
def tables():
    """The folder of this build's tables, reference/db2/<build>: the newest."""
    return max(DB2.iterdir())


@cache
def modified_click_defaults():
    """Forever's default key for each modified click: { action: "SHIFT-BUTTON1" }."""
    return dict(re.findall(r'<ModifiedClick action="(\w+)" default="([^"]*)"', BINDINGS.read_text(encoding="utf-8", errors="replace")))


@cache
def map_types():
    """Each map's type in this build, as C_Map.GetMapInfo gives it: { uiMapID: type }."""
    with open(tables() / "UiMap.csv", encoding="utf-8", newline="") as f:
        return {int(r["ID"]): int(r["Type"]) for r in csv.DictReader(f)}


@cache
def atlas_names():
    """Every atlas this build's tables name, in lower case, as the game matches them."""
    names = set()
    for file, column in (("UiTextureAtlasElement.csv", "Name"), ("UiTextureAtlasMember.csv", "CommittedName")):
        with open(tables() / file, encoding="utf-8", newline="") as f:
            names.update(row[column].lower() for row in csv.DictReader(f))
    return names


@cache
def global_api_names():
    """The game's own global functions, by BlizzardInterfaceResources' list."""
    return frozenset(re.findall(r'^\s*"(\w+)",', GLOBAL_API.read_text(encoding="utf-8"), re.M))


# ---------- Blizzard's own source ----------

def blizzard_addon(path):
    return path.relative_to(UI_SOURCE / "AddOns").parts[0]


@cache
def ui_source():
    """What Blizzard's own Lua and XML define and call (read_ui_source), kept from one run to the next while its
    source and this file stay the same."""
    return kept("ui-source", (stamps(UI_SOURCE, (".lua", ".xml")), files(__file__)), read_ui_source)


def ui_source_names():
    """The C_ functions Blizzard's own Lua calls, the global names it defines, the methods it defines, and which of its
    addons define each global, each template and each font."""
    return ui_source()[0]


def blizzard_enums():
    """The Enum tables and members Blizzard's own Lua names: { enum: { member } }. Some, such as Enum.GameRule, are
    missing from the docs but read by Blizzard's own code, so the game has them."""
    return ui_source()[1]


def read_ui_source():
    """ui_source()'s, read in one pass: (the names, Blizzard's enums)."""
    c_names, globals_, methods = set(), set(), set()
    defined_in, templates_in, fonts_in, enums = {}, {}, {}, {}
    for path in UI_SOURCE.rglob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        c_names.update(re.findall(r"\b(C_\w+\.\w+)\(", text))
        names = set(re.findall(r"^function\s+(\w+)\s*\(", text, re.M)) | set(re.findall(r"^(\w+)\s*=", text, re.M))
        globals_.update(names)
        for name in names:
            defined_in.setdefault(name, set()).add(blizzard_addon(path))
        methods.update(re.findall(r"function\s+[\w.]+[:.](\w+)\s*\(", text))
        methods.update(re.findall(r"^\s*(\w+)\s*=\s*function", text, re.M))
        for enum, member in re.findall(r"\bEnum\.(\w+)(?:\.(\w+))?", text):
            enums.setdefault(enum, set())
            if member:
                enums[enum].add(member)
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
    return (c_names, globals_, methods, defined_in, templates_in, fonts_in), enums


# ---------- The API documentation ----------

def api_docs_reader(read):
    """A reader of this build's API docs (its folder's .lua files), read once a process and kept from one run to the
    next while the docs and this file stay the same."""
    @wraps(read)
    def reader():
        return kept(read.__name__, (stamps(API_DOCS, (".lua",), False), files(__file__)), read)
    return cache(reader)


@api_docs_reader
def doc_function_names():
    """Every namespaced function of this build's API docs: { "C_Namespace.Function" }."""
    names = set()
    for path in API_DOCS.glob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        namespace = re.search(r'Namespace = "(\w+)"', text)
        if not namespace:
            continue
        for fn in re.findall(r'Name = "(\w+)",\s*Type = "Function"', text):
            names.add(f"{namespace.group(1)}.{fn}")
    return frozenset(names)


@api_docs_reader
def doc_method_names():
    """Every function name of this build's API docs, a widget's method or a namespace's function."""
    names = set()
    for path in API_DOCS.glob("*.lua"):
        names.update(re.findall(r'Name = "(\w+)",\s*Type = "Function"', path.read_text(encoding="utf-8", errors="replace")))
    return frozenset(names)


@api_docs_reader
def documented_enums():
    """Every enumeration in this build's API docs: { name: { member: value } }."""
    enums = {}
    for path in API_DOCS.glob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'Name = "(\w+)",\s*Type = "Enumeration",.*?Fields =\s*\{(.*?)\n\t\t\t\}', text, re.S):
            enums[m.group(1)] = {n: int(v) for n, v in re.findall(r'Name = "(\w+)", Type = "\w+", EnumValue = (-?\d+)', m.group(2))}
    return enums


@api_docs_reader
def doc_event_names():
    """Every event of this build's API docs."""
    events = set()
    for path in API_DOCS.glob("*.lua"):
        events.update(re.findall(r'LiteralName = "(\w+)"', path.read_text(encoding="utf-8", errors="replace")))
    return frozenset(events)


# A function's entry in the API docs, and the annotations on it that say its results may come as secret values: ones
# an addon can keep and pass on, but not compare, join to text or look inside (an error each time).
DOC_FUNCTION = re.compile(r'\n\t\t\{\n\t\t\tName = "(\w+)",\n\t\t\tType = "Function",(.*?)\n\t\t\},', re.S)
SECRET_RESULT = re.compile(r"^\t\t\t(Secret(?:When|In|On)\w+|SecretReturns) = true,", re.M)


@api_docs_reader
def secret_functions():
    """The game's functions whose results it may hide from addons, by this build's API docs: { name: { annotation } }.
    Widgets' methods aren't in it: theirs are hidden only on Blizzard's own objects."""
    out = {}
    for path in API_DOCS.glob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if not re.search(r'^\tType = "System",', text, re.M):
            continue
        namespace = re.search(r'^\tNamespace = "(\w+)"', text, re.M)
        prefix = namespace.group(1) + "." if namespace else ""
        for name, body in DOC_FUNCTION.findall(text):
            kinds = set(SECRET_RESULT.findall(body + "\n"))
            if kinds:
                out[prefix + name] = kinds
    return out
