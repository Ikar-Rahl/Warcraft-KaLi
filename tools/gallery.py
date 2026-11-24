"""The pictures of an addon's CurseForge page, in the repository (Ikar 2026-11-24: "I also want all images to be in
GitHub. So I can download them and put them in curseforge"). The screenshots are taken in game and prepared outside the
repository (PNG, in release/<Addon>-<version>/gallery/ beside it, other players' names blurred there); this writes each
as a JPEG at most 1920 wide into <addon>/docs/images/ under the same name, and copies the logo as it is. The READMEs
link some of them through github.com, so the description's pictures follow main; the Gallery's are uploaded by hand.

Some are put together here (MADE):
- KaLi HUD's 02-nine-styles, from the nine style strips, 13 to 21, each whole under its name: the chat's and the damage
  meter's cartouches at the ends are part of the style (Ikar 2026-11-24: "The combined image of the style leave out the
  cartouche, which are a big part of the style"). The description's; for the Gallery, the same in two, 02a with four
  styles and 02b with five ("The 9 style read poorly on an image. Fine in the description, but not as a standalone
  page, maybe make one with 4 and another with 5 ?").
- A hero, the Gallery's first picture ("I also lack a hero page"): the logo, the name and the summary over the addon's
  own screenshots, 1920 x 1080: KaLi HUD's, the plate along the foot, two features above it, and three styles' minimap
  rings on the right, Forest, Astronomy, Steampunk, unnamed (Ikar: "I like plate", the rings' order, "3, no names").

Headless Edge does the drawing, as hud/tools/cut_rings.py: no image library to install. One page an image. No font of
Blizzard's: Georgia and Segoe UI, Windows' own.

    python -I tools/gallery.py hud                 what docs/images lacks: the logo, and each picture not there
    python -I tools/gallery.py hud 02a 00-hero   the pictures named (by name, its number, or a part of it), again
"""
import base64
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kali.paths import EDGE, ROOT  # noqa: E402
from kali.shared import ADDONS  # noqa: E402

RELEASES = ROOT.parent / "release"
WIDEST = 1920
QUALITY = 0.9
TITLES = {"quest": "KaLi Quest", "recipe": "KaLi Recipe", "hud": "KaLi HUD"}

# The pictures put together from others: their layout, the pictures they're made of (by the start of their name, LOGO
# for the logo), and the addon's strings naming each part.
STYLES = ["blizzard", "steel", "golden", "forest", "rune", "steampunk", "gem", "astronomy", "fire"]
STRIPS = [f"{13 + i}-style-" for i in range(9)]
PRESETS = [f"PRESET_{s}" for s in STYLES]
MADE = {
    "hud": {
        "02-nine-styles": {"kind": "styles", "sources": STRIPS, "labels": PRESETS},
        "02a-four-styles": {"kind": "styles", "sources": STRIPS[:4], "labels": PRESETS[:4]},
        "02b-five-styles": {"kind": "styles", "sources": STRIPS[4:], "labels": PRESETS[4:]},
        "00-hero": {"kind": "hero-plate", "sources": ["LOGO", "13-style-", "04-attribute-cards", "05-a-folder",
                                                     STRIPS[3], STRIPS[7], STRIPS[5]]},
    },
    # Their heroes, the split of five proposals (Ikar 2026-11-24: "Also make 5 proposal for the other 2 add-ons", then
    # "Go for 2 and 2, the 3 show settings. Not something for a hero page"): the name on the left, one screenshot large.
    "quest": {
        "00-hero": {"kind": "hero", "layout": "split", "sources": ["LOGO", "01-your-groups"]},
    },
    "recipe": {
        "00-hero": {"kind": "hero", "layout": "split", "sources": ["LOGO", "03-the-notebook"]},
    },
}

PAGE = """<!doctype html><meta charset="utf-8"><pre id="export"></pre>
<script>
(async () => {
  const job = DATA;
  const load = url => new Promise((ok, fail) => { const i = new Image(); i.onload = () => ok(i); i.onerror = fail; i.src = url; });
  const images = await Promise.all(job.sources.map(load));
  const c = document.createElement("canvas"), g = c.getContext("2d");
  const size = (w, h) => { c.width = w; c.height = h; g.imageSmoothingEnabled = true; g.imageSmoothingQuality = "high"; };
  // A style strip's minimap dome, square, where it sits in each: at the middle, on the foot of the strip.
  const dome = im => { const k = im.naturalWidth / 3835, s = 470 * k;
    return [im.naturalWidth * 0.5038 - s / 2, im.naturalHeight - s - 5 * k, s, s]; };
  const gold = (y0, y1) => { const gr = g.createLinearGradient(0, y0, 0, y1);
    gr.addColorStop(0, "#fbe7a1"); gr.addColorStop(0.55, "#e2b450"); gr.addColorStop(1, "#a8741f"); return gr; };
  const ground = (w, h) => { const gr = g.createRadialGradient(w * 0.35, h * 0.3, 40, w * 0.5, h * 0.5, w * 0.8);
    gr.addColorStop(0, "#2b2219"); gr.addColorStop(1, "#0b0806"); g.fillStyle = gr; g.fillRect(0, 0, w, h); };
  // Lines of even length: a summary a little too long breaks in two halves, not before its last word.
  const wrap = (text, x, y, width, line) => { let row = "";
    const full = g.measureText(text).width;
    if (full > width) width = Math.min(width, full / Math.ceil(full / width) + 60);
    for (const word of text.split(" ")) { const next = row ? row + " " + word : word;
      if (g.measureText(next).width > width && row) { g.fillText(row, x, y); y += line; row = word; } else row = next; }
    if (row) g.fillText(row, x, y); return y; };
  const card = (im, s, x, y, w, h) => { g.save(); g.shadowColor = "rgba(0,0,0,0.75)"; g.shadowBlur = 26;
    g.fillStyle = "#000"; g.fillRect(x, y, w, h); g.restore(); g.drawImage(im, ...s, x, y, w, h);
    g.strokeStyle = "#7a6136"; g.lineWidth = 2; g.strokeRect(x + 1, y + 1, w - 2, h - 2); };
  const whole = im => [0, 0, im.naturalWidth, im.naturalHeight];

  if (job.kind === "plain") {
    const im = images[0], k = Math.min(1, job.widest / im.naturalWidth);
    size(Math.round(im.naturalWidth * k), Math.round(im.naturalHeight * k));
    g.drawImage(im, 0, 0, c.width, c.height);
  } else if (job.kind === "styles") {
    // A strip under its name, each whole, on the dark ground of the first composite.
    const margin = 20, font = 30, line = 52, gap = 26, inner = job.widest - 2 * margin;
    const rows = images.map(im => Math.round(im.naturalHeight * inner / im.naturalWidth));
    size(job.widest, margin + rows.reduce((a, h) => a + line + h + gap, 0) - gap + margin);
    g.fillStyle = "#120e0a"; g.fillRect(0, 0, c.width, c.height);
    let y = margin;
    images.forEach((im, n) => {
      g.fillStyle = "#ffd100"; g.font = `${font}px Georgia, serif`;
      g.fillText(job.labels[n], margin, y + font);
      y += line;
      g.drawImage(im, margin, y, inner, rows[n]);
      y += rows[n] + gap;
    });
  } else if (job.kind === "hero-plate") {
    // The name and the summary above, two of its features in the middle, the plate along the foot as in the game.
    const W = 1920, H = 1080, [logo, strip, cards, folder, ...rings] = images;
    size(W, H); ground(W, H);
    const sh = Math.round(strip.naturalHeight * W / strip.naturalWidth), stripTop = H - sh;
    g.drawImage(strip, 0, stripTop, W, sh);
    const fade = g.createLinearGradient(0, stripTop, 0, stripTop + 80);
    fade.addColorStop(0, "rgba(11,8,6,1)"); fade.addColorStop(1, "rgba(11,8,6,0)");
    g.fillStyle = fade; g.fillRect(0, stripTop, W, 80);
    g.drawImage(logo, 120, 70, 250, 250);
    g.font = "bold 124px Georgia, serif"; g.fillStyle = gold(110, 240); g.fillText(job.title, 410, 215);
    // A column of styles' minimap rings on the right, in the order given, without their names (Ikar 2026-11-24: "I
    // like plate, but can you make also 3 or 4 rigs on the right ?", "Forest first, astronomy, steampunk and fire,
    // that order", then "3, no names").
    let right = W - 70;
    if (rings.length) {
      const gap = 14, tile = Math.floor((stripTop - 30 - 40 - (rings.length - 1) * gap) / rings.length);
      const x = W - 70 - tile;
      rings.forEach((im, n) => card(im, dome(im), x, 40 + n * (tile + gap), tile, tile));
      right = x - 40;
    }
    g.font = "38px 'Segoe UI', sans-serif"; g.fillStyle = "#eadfc4";
    wrap(job.tagline, 416, 285, Math.min(1380, right - 416), 50);
    // Two of its features between the summary and the plate, as large as the room left lets them.
    const top = 400, room = stripTop - 30 - top;
    let h = room, cw = cards.naturalWidth * h / cards.naturalHeight;
    let fw = folder.naturalWidth * h / folder.naturalHeight;
    const k = Math.min(1, (right - 120 - 70) / (cw + fw));
    h *= k; cw *= k; fw *= k;
    const x0 = Math.round(120 + (right - 120 - (cw + 70 + fw)) / 2), y0 = Math.round(top + (room - h) / 2);
    card(cards, whole(cards), x0, y0, Math.round(cw), Math.round(h));
    card(folder, whole(folder), Math.round(x0 + cw + 70), y0, Math.round(fw), Math.round(h));
  } else if (job.kind === "hero") {
    // KaLi Quest's and KaLi Recipe's, five layouts to choose from (Ikar 2026-11-24: "Also make 5 proposal for the
    // other 2 add-ons"), in KaLi HUD's look: the name in gold, the logo, the addon's own screenshots as cards.
    const W = 1920, H = 1080, [logo, ...shots] = images;
    size(W, H); ground(W, H);
    const fit = (im, bw, bh) => { const k = Math.min(bw / im.naturalWidth, bh / im.naturalHeight);
      return [Math.round(im.naturalWidth * k), Math.round(im.naturalHeight * k)]; };
    const head = width => {
      g.drawImage(logo, 120, 70, 250, 250);
      g.font = "bold 124px Georgia, serif"; g.fillStyle = gold(110, 240); g.fillText(job.title, 410, 215);
      g.font = "38px 'Segoe UI', sans-serif"; g.fillStyle = "#eadfc4"; wrap(job.tagline, 416, 285, width, 50); };
    if (job.layout === "row") {
      // The name on top, the screenshots side by side below, one height, as large as the width lets them.
      head(1380);
      const top = 410, bottom = H - 50, gap = 60, room = W - 240 - gap * (shots.length - 1);
      let h = bottom - top, ws = shots.map(im => im.naturalWidth * h / im.naturalHeight);
      const sum = ws.reduce((a, b) => a + b, 0), k = Math.min(1, room / sum);
      h *= k; ws = ws.map(w => w * k);
      let x = (W - (sum * k + gap * (shots.length - 1))) / 2;
      const y = Math.round(top + (bottom - top - h) / 2);
      shots.forEach((im, n) => { card(im, whole(im), Math.round(x), y, Math.round(ws[n]), Math.round(h)); x += ws[n] + gap; });
    } else if (job.layout === "split") {
      // The name on the left, one screenshot large on the right.
      g.drawImage(logo, 140, 150, 300, 300);
      g.font = "bold 124px Georgia, serif"; g.fillStyle = gold(500, 620); g.fillText(job.title, 130, 600);
      g.font = "38px 'Segoe UI', sans-serif"; g.fillStyle = "#eadfc4"; wrap(job.tagline, 136, 680, 760, 52);
      const [w, h] = fit(shots[0], 880, 960);
      card(shots[0], whole(shots[0]), Math.round(980 + (880 - w) / 2), Math.round((H - h) / 2), w, h);
    } else if (job.layout === "center") {
      // The logo and the name centred on top, the summary under them, one wide screenshot below.
      g.font = "bold 110px Georgia, serif";
      const ls = 160, x0 = (W - (ls + 36 + g.measureText(job.title).width)) / 2;
      g.drawImage(logo, x0, 50, ls, ls);
      g.fillStyle = gold(80, 190); g.fillText(job.title, x0 + ls + 36, 170);
      g.font = "36px 'Segoe UI', sans-serif"; g.fillStyle = "#eadfc4"; g.textAlign = "center";
      g.fillText(job.tagline, W / 2, 268); g.textAlign = "left";
      const [w, h] = fit(shots[0], 1600, 720);
      card(shots[0], whole(shots[0]), Math.round((W - w) / 2), Math.round(320 + (720 - h) / 2), w, h);
    } else if (job.layout === "cascade") {
      // The name on the left, the screenshots overlapping down to the right.
      const sized = shots.map(im => fit(im, 600, 600)), sx = 110, sy = 135;
      const x0 = Math.min(1180, W - 70 - Math.max(...sized.map(([w], n) => n * sx + w)));
      // Below the name when it reaches under it.
      g.font = "bold 124px Georgia, serif";
      const under = x0 < 410 + g.measureText(job.title).width + 30;
      const y0 = Math.min(under ? 250 : 220, H - 40 - Math.max(...sized.map(([, h], n) => n * sy + h)));
      head(Math.min(740, x0 - 456));
      shots.forEach((im, n) => card(im, whole(im), x0 + n * sx, y0 + n * sy, ...sized[n]));
    } else if (job.layout === "band") {
      // The name on top, one wide screenshot filling the foot, as KaLi HUD's plate.
      head(1380);
      const im = shots[0], k = W / im.naturalWidth, top = 400;
      g.drawImage(im, 0, 0, im.naturalWidth, (H - top) / k, 0, top, W, H - top);
      const fade = g.createLinearGradient(0, top, 0, top + 90);
      fade.addColorStop(0, "rgba(11,8,6,1)"); fade.addColorStop(1, "rgba(11,8,6,0)");
      g.fillStyle = fade; g.fillRect(0, top, W, 90);
    }
  }
  document.getElementById("export").textContent =
    JSON.stringify({ w: c.width, h: c.height, jpeg: c.toDataURL("image/jpeg", job.quality) });
})();
</script>"""


def draw(job):
    work = Path(tempfile.mkdtemp(prefix="kali-gallery-"))
    try:
        page = work / "draw.html"
        page.write_text(PAGE.replace("DATA", json.dumps(job), 1), encoding="utf-8")
        result = subprocess.run(
            [str(EDGE), "--headless=new", "--disable-gpu", f"--user-data-dir={work / 'profile'}",
             "--allow-file-access-from-files", "--virtual-time-budget=60000", "--dump-dom", page.as_uri()],
            capture_output=True, text=True, encoding="utf-8", timeout=300)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    found = re.search(r'<pre id="export">(.+?)</pre>', result.stdout, re.S)
    if not found:
        raise SystemExit(f"the page drew nothing\n{result.stderr[-2000:]}")
    return json.loads(found.group(1))


def strings(addon_dir, addon):
    text = (addon_dir / addon / "Locale" / "enUS.lua").read_text(encoding="utf-8")
    return dict(re.findall(r'^\s*(\w+) = "(.*)",\s*$', text, re.M))


def summary(addon_dir, addon):
    """The TOC's Notes, the English one: the CurseForge summary (Ikar's, 2026-11-23, for KaLi HUD)."""
    toc = (addon_dir / addon / f"{addon}.toc").read_text(encoding="utf-8")
    return re.search(r"^## Notes:\s*(.*?)\s*$", toc, re.M).group(1)


def version_key(folder):
    return [int(n) for n in re.findall(r"\d+", folder.name.rsplit("-", 1)[-1])]


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ADDONS:
        raise SystemExit(__doc__)
    key, wanted = sys.argv[1], sys.argv[2:]
    addon_dir, addon = ADDONS[key]
    folders = sorted((p for p in RELEASES.glob(f"{addon}-*") if (p / "gallery").is_dir()), key=version_key)
    if not folders:
        raise SystemExit(f"no {RELEASES / (addon + '-<version>') / 'gallery'}")
    release = folders[-1]
    gallery = sorted((release / "gallery").glob("*.png"))
    logo = release / f"{addon}-logo-400.png"
    out = ROOT / key / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    made = MADE.get(key, {})

    def chosen(stem):
        if wanted:
            return any(stem == w or stem.split("-", 1)[0] == w or w in stem for w in wanted)
        return not (out / f"{stem}.jpg").exists()

    def source(prefix):
        return logo if prefix == "LOGO" else next(p for p in gallery if p.name.startswith(prefix))

    if logo.exists() and (not wanted and not (out / logo.name).exists() or "logo" in wanted):
        shutil.copyfile(logo, out / logo.name)
        print(f"{out.relative_to(ROOT).as_posix()}/{logo.name}: copied")
    names = strings(addon_dir, addon)
    for stem in sorted({p.stem for p in gallery} | set(made)):
        if not chosen(stem):
            continue
        if stem in made:
            recipe = made[stem]
            job = {"kind": recipe["kind"], "layout": recipe.get("layout"),
                   "sources": [source(s).as_uri() for s in recipe["sources"]],
                   "labels": [names[label] for label in recipe.get("labels", [])],
                   "title": TITLES[key], "tagline": summary(addon_dir, addon)}
        else:
            job = {"kind": "plain", "sources": [next(p for p in gallery if p.stem == stem).as_uri()]}
        job.update(widest=WIDEST, quality=QUALITY)
        result = draw(job)
        target = out / f"{stem}.jpg"
        target.write_bytes(base64.b64decode(result["jpeg"].split(",", 1)[1]))
        print(f"{target.relative_to(ROOT).as_posix()}: {result['w']} x {result['h']}, {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
