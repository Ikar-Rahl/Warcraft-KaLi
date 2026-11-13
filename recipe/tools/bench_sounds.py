"""Give the bench the addon's sounds, to be heard before choosing (Ikar, 2026-11-10).

Reads the choices from the addon itself (KaLiRecipe/Core/Sounds.lua) and their French and English labels
(Core/Locale.lua), finds each kit's files and volume in this build's tables (SoundKit, SoundKitEntry), downloads the
files from this build's game data on wago.tools (cached, as the benches' art is), and writes
recipe/bench/js/sounds.js with each sound's length, read from its Ogg pages. The files land in
recipe/bench/art/sounds/: Blizzard's, for local development only, like the rest of art/.

recipe/tools/run_tests.py fails when sounds.js no longer lists the addon's choices. Run with:
python -I recipe/tools/bench_sounds.py
"""
import csv
import json
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from kali.art import BUILD, CASC, fetch  # noqa: E402
from kali.paths import RECIPE, REFERENCE, ROOT, use_pylib  # noqa: E402

use_pylib()
import lupa.lua51 as lupa  # noqa: E402

ADDON = RECIPE / "addon/KaLiRecipe"
DB2 = REFERENCE / "db2" / BUILD
SOUNDKIT_LUA = REFERENCE / "wow-ui-source/Interface/AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua"
OUT = RECIPE / "bench/art/sounds"
JS = RECIPE / "bench/js/sounds.js"

# What the game plays each for, for the bench's notes. Bench only.
USES = {
    "quill": "the quest log's quill, when a quest is accepted: three takes of 2.2 to 3 s, one at random",
    "note": "the same quill, stopped after 0.9 s and fading out",
    "stroke": "the same quill, stopped after 0.4 s and fading out",
    "parchment": "the bags' sound for a paper item laid down",
    "sheet": "the bags' sound for a paper item picked up",
}


def addon_lists():
    """The addon's own choices and labels, by running its two files on Lua 5.1."""
    out = {}
    for locale in ("frFR", "enUS"):
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(f'function GetLocale() return "{locale}" end')
        ns = lua.table()
        for name in ("Core/Locale.lua", "Core/Sounds.lua"):
            chunk = lua.eval("loadstring")((ADDON / name).read_text(encoding="utf-8"), "@" + name)
            chunk("KaLiRecipe", ns)
        L, S = ns.L, ns.Sounds
        out[locale] = {
            "choices": {kind: [[c[1], c[2], c[3], c[4]] for c in S.CHOICES[kind].values()] for kind in ("recipe", "place")},
            "defaults": {kind: S.DEFAULTS[kind] for kind in ("recipe", "place")},
            "labels": lambda key, L=L: L["SOUND_" + key],
            "options": {k: L[k] for k in ("OPT_CHAT_SECTION", "OPT_SOUND_RECIPE", "OPT_SOUND_RECIPE_TIP", "OPT_SOUND_PLACE",
                                          "OPT_SOUND_PLACE_TIP", "SOUND_NONE")},
            "quiet": S.QUIET,
            "fade": S.FADE,
        }
    return out


def duration(data):
    """An Ogg Vorbis file's length in seconds: the last page's granule position over the stream's sample rate."""
    rate, granule, i = None, 0, 0
    while (i := data.find(b"OggS", i)) >= 0:
        g = struct.unpack_from("<q", data, i + 6)[0]
        body = i + 27 + data[i + 26]
        if rate is None and data[body:body + 7] == b"\x01vorbis":
            rate = struct.unpack_from("<I", data, body + 12)[0]
        if g > 0:
            granule = g
        i += 4
    return round(granule / rate, 2) if rate else None


def main():
    lists = addon_lists()
    names = {k: int(v) for k, v in re.findall(r"^\s*([A-Z0-9_]+)\s*=\s*(\d+)", SOUNDKIT_LUA.read_text(encoding="utf-8"), re.M)}
    with open(DB2 / "SoundKit.csv", encoding="utf-8", newline="") as f:
        volume = {int(r["ID"]): float(r["VolumeFloat"]) for r in csv.DictReader(f)}
    files = {}
    with open(DB2 / "SoundKitEntry.csv", encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            files.setdefault(int(r["SoundKitID"]), []).append(int(r["FileDataID"]))
    OUT.mkdir(parents=True, exist_ok=True)
    fr, en = lists["frFR"], lists["enUS"]
    kinds = {}
    for kind, choices in fr["choices"].items():
        kinds[kind] = []
        for key, kit, check, stop in choices:
            kit = int(kit)
            named = names.get(check) == kit if isinstance(check, str) else int(check) in files.get(kit, [])
            if not named or kit not in volume or kit not in files:
                raise SystemExit(f"{key}: kit {kit} ({check}) isn't this build's: fix Core/Sounds.lua")
            takes = []
            for fdid in sorted(files[kit]):
                dest = OUT / f"{fdid}.ogg"
                data = fetch(CASC.format(fdid), dest)
                if data[:4] != b"OggS":
                    raise SystemExit(f"{key}: file {fdid} isn't Ogg")
                takes.append({"file": f"art/sounds/{fdid}.ogg", "seconds": duration(data)})
            kinds[kind].append({"key": key, "kit": kit, "name": check if isinstance(check, str) else f"file {int(check)}",
                                "stop": stop, "fr": fr["labels"](key), "en": en["labels"](key),
                                "volume": round(volume[kit], 3), "takes": takes, "use": USES.get(key, "")})
            print(f"{kind:6} {key:10} kit {kit:>6}  volume {volume[kit]:.2f}  " + ", ".join(f"{t['seconds']}s" for t in takes)
                  + (f"  stopped at {stop}s" if stop else ""))
    data = {"build": BUILD, "defaults": fr["defaults"], "quiet": fr["quiet"], "fade": fr["fade"],
            "options": {"fr": fr["options"], "en": en["options"]},
            "kinds": kinds}
    JS.write_text("// Made by recipe/tools/bench_sounds.py from the addon's Core/Sounds.lua and this build's sound\n"
                  "// tables: the sounds the in-game options offer, to hear them on the bench.\n"
                  "window.SOUNDS = " + json.dumps(data, ensure_ascii=False, indent=1) + ";\n", encoding="utf-8", newline="\n")
    print("written", JS.relative_to(ROOT))


if __name__ == "__main__":
    main()
