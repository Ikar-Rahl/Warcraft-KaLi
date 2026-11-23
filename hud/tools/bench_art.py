"""The benches' art: the game's backgrounds the KaLi HUD offers as materials (Core/Init.lua's ns.MATERIALS), the
minimap's ring and an action button's frame to dress the scenes, and the game's font, for hud/bench/borders.html and
hud/bench/cartouche.html.
Blizzard's art stays local (hud/.gitignore keeps bench/art/ out). Everything downloaded is cached, so a re-run is quick.

Run with: python -I hud/tools/bench_art.py
"""
import io
import json
import re
import shutil
import struct
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from kali.art import CASC, decode_blp, fetch, write_png  # noqa: E402
from kali.paths import REFERENCE  # noqa: E402

HUD = ROOT / "hud"
OUT = HUD / "bench/art"
CACHE = OUT / "_cache"
JS_OUT = HUD / "bench/js/art-data.js"
ATLAS_INFO = REFERENCE / "BlizzardInterfaceResources/Resources/AtlasInfo.lua"
RAW = "https://raw.githubusercontent.com/Gethe/wow-ui-textures/live/"
sys.stdout.reconfigure(encoding="utf-8")

ATLASES = ["UI-HUD-Minimap-Frame", "UI-HUD-ActionBar-IconFrame", "UI-Background-Rock-Brown", "bank-frame-background",
           "UI-Frame-Dragonflight-BackgroundTile", "GarrLanding-MiddleTile", "gamepad-mapquestlog-bgtile-2k",
           "UI-Frame-Neutral-BackgroundTile", "UI-Frame-Alliance-BackgroundTile", "AdventureMap_TileBg_Parchment",
           # cartouche.html: Forever's own plaques and headers.
           "ui-hud-minimap-header-button", "UI-Character-Info-Title", "UI-Frame-DiamondMetal-Header-CornerLeft",
           "_UI-Frame-DiamondMetal-Header-Tile", "UI-Frame-DiamondMetal-Header-CornerRight", "Legacy-Tree-Frame-Points-Bar",
           "ui-damagemeters-header-bar", "UI-QuestTracker-Secondary-Objective-Header", "common-internaltab",
           "UI-Notification-condense"]
# UI/Border.lua's BACKGROUNDS, from a mirror of the game's interface textures.
FILES = {
    "UI-DialogBox-Background-Dark": "DialogFrame/UI-DialogBox-Background-Dark",
    "UI-Background-Marble": "FrameGeneral/UI-Background-Marble",
    "UI-Background-Rock": "FrameGeneral/UI-Background-Rock",
}


def parse_atlas_info():
    """name (lower case) -> [ { name, sheet, fdid, w, h, l, r, t, b } ]."""
    out = {}
    sheet = fdid = None
    for line in ATLAS_INFO.read_text(encoding="utf-8").splitlines():
        m = re.match(r'^\t\["([^"]+)"\] = \{ -- (\d+)', line)
        if m:
            sheet, fdid = m.group(1), int(m.group(2))
            continue
        m = re.match(r'^\t\t\["([^"]+)"\] = \{(\d+), (\d+), ([^,]+), ([^,]+), ([^,]+), ([^,]+)', line)
        if m and sheet:
            out.setdefault(m.group(1).lower(), []).append({
                "name": m.group(1), "sheet": sheet, "fdid": fdid, "w": int(m.group(2)), "h": int(m.group(3)),
                "l": float(m.group(4)), "r": float(m.group(5)), "t": float(m.group(6)), "b": float(m.group(7)),
            })
    return out


def pick(entries):
    """Forever's c60 art when the game has it (it draws that), its sharpest sheet; the logical size of its 1x."""
    c60 = [e for e in entries if "c60" in e["sheet"]]
    pool = c60 or entries
    best = max(pool, key=lambda e: e["w"])
    logical = min(pool, key=lambda e: e["w"])
    if logical is best and "2x" in best["sheet"]:
        return best, best["w"] // 2, best["h"] // 2
    return best, logical["w"], logical["h"]


def crop(fdid, l, r, t, b):
    w, h, rgba = decode_blp(fetch(CASC.format(fdid), CACHE / f"{fdid}.blp"))
    x0, x1 = round(l * w), round(r * w)
    y0, y1 = round(t * h), round(b * h)
    cw, ch = max(1, x1 - x0), max(1, y1 - y0)
    rows = bytearray()
    for y in range(y0, y0 + ch):
        start = (y * w + x0) * 4
        rows += rgba[start:start + cw * 4]
    return cw, ch, bytes(rows)


def atlas_png(info, name):
    entries = info.get(name.lower())
    if not entries:
        return None
    best, lw, lh = pick(entries)
    dest = OUT / "atlas" / (re.sub(r"[^\w.-]", "_", best["name"]) + ".png")
    if not dest.exists():
        cw, ch, rgba = crop(best["fdid"], best["l"], best["r"], best["t"], best["b"])
        write_png(dest, cw, ch, rgba)
    return {"src": f"art/atlas/{dest.name}", "w": lw, "h": lh}


def mirror_file(path):
    """A classic file from the mirror; its folders' case varies, so a few spellings are tried."""
    folder, _, base = path.rpartition("/")
    for f in (folder, folder.upper(), folder.lower()):
        for ext in (".PNG", ".png"):
            url = RAW + f + "/" + base + ext
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "wow-addon-testbench"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    return r.read()
            except urllib.error.HTTPError:
                continue
    return None


def png_size(blob):
    return struct.unpack(">II", blob[16:24])


# cartouche.html: free art from OpenGameArt (each shape there names its author and licence): dest -> url, zip member.
OGA = "https://opengameart.org/sites/default/files/"
FREE = {
    "cethiel-bar.png": (OGA + "HUD.zip", "Bars/Others/Horizontal/Bar_0.png"),
    "wyrmheart-ui.png": (OGA + "muestra-final.png", None),
    "lamoot-rpg-gui.png": (OGA + "rpg_gui_v1.png", None),
    "ege-banner.png": (OGA + "status%20frame_1.png", None),
    "kenney-border.png": (OGA + "kenney_fantasy-ui-borders.zip", "PNG/Double/Border/panel-border-007.png"),
}


def free_art():
    (OUT / "free").mkdir(parents=True, exist_ok=True)
    for dest, (url, member) in FREE.items():
        path = OUT / "free" / dest
        if path.exists():
            continue
        cached = CACHE / re.sub(r"[^\w.-]", "_", url.rsplit("/", 1)[-1])
        if not cached.exists():
            # OpenGameArt refuses unknown agents.
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
            with urllib.request.urlopen(req, timeout=120) as r:
                cached.write_bytes(r.read())
        blob = cached.read_bytes()
        if member:
            blob = zipfile.ZipFile(io.BytesIO(blob)).read(member)
        path.write_bytes(blob)


def main():
    for sub in ("atlas", "file"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    info = parse_atlas_info()
    data = {"atlas": {}, "files": {}}
    missing = []
    for name in ATLASES:
        piece = atlas_png(info, name)
        if piece:
            data["atlas"][name] = piece
        else:
            missing.append(name)
    for key, path in FILES.items():
        dest = OUT / "file" / f"{key}.png"
        if not dest.exists():
            blob = mirror_file(path)
            if not blob:
                missing.append(path)
                continue
            dest.write_bytes(blob)
        w, h = png_size(dest.read_bytes())
        data["files"][key] = {"src": f"art/file/{key}.png", "w": w, "h": h}
    for src, dest in ((ROOT / "quest/bench/art/FRIZQT__.TTF", OUT / "FRIZQT__.TTF"),):
        if src.exists() and not dest.exists():
            shutil.copyfile(src, dest)
    free_art()
    if missing:
        print("missing:", ", ".join(missing))
    JS_OUT.write_text("// Generated by hud/tools/bench_art.py. Don't edit.\nwindow.HUD_ART = "
                      + json.dumps(data, indent=1) + ";\n", encoding="utf-8", newline="\n")
    print(f"written {JS_OUT}: {len(data['atlas'])} atlases, {len(data['files'])} files")


if __name__ == "__main__":
    main()
