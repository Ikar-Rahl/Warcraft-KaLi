"""Every text an addon draws in a room of a fixed size fits it, in each language the addon speaks.

The shared dialog (Shared/Dialog.lua) and the options page (Shared/Page.lua) are drawn at Blizzard's sizes: the label
of a slider, of a dropdown or of a button's row is 100 wide and two lines tall, an options row's name is one line, up
to 85 short of the row's middle. The game cuts a text too long for its room with an ellipsis, and only a player in
that language sees it: Ikar plays in French. Found on 2026-11-16 in the German and Spanish written that day, and in
French labels cut since their sliders went to the dialog three days before.

The texts are those the smoke session drew, in French, the fake game's language. Each is looked up in the addon's own
strings, and every language's string under the same key is measured for the same place, with the game's own font,
Friz Quadrata, from the advance widths in its file. A text the game gives (ns.G) has no key and isn't measured: it is
Blizzard's to fit.

The font is Blizzard's and stays out of the repository: it is read from a bench's art folder
(<addon>/bench/art/FRIZQT__.TTF), and without it the check says so and passes.

How close the measure is: Blizzard's own labels for the same 100, measured the same way, top out at 99.3 in French
("Limite d’icônes") and 92.2 in English, and its German breaks by hand a word that measures 101.5
("Symbol-\\nabstand"). The game rounds each glyph to the screen's pixels, which this doesn't know, so a text must
still fit with every glyph SLACK wider.
"""
import struct

from kali.paths import ROOT

FONT_NAME = "FRIZQT__.TTF"
SLACK = 1.04
# Where a text goes: its room's width, its font's height and the lines it may take. The heights are those of
# Blizzard_Fonts_Shared/Shared/Fonts.xml: GameFontHighlightMedium is Friz Quadrata 14, GameFontNormal and
# GameFontHighlight 12.
ROOMS = {
    # EditModeSettingSliderTemplate's and EditModeSettingDropdownTemplate's Label: 100 by 32.
    "label": (100, 14, 2, "a label of the dialog, 100 wide, two lines"),
    # EditModeSettingCheckboxTemplate: from the box, which ends 32 in, to the right of a row 343 wide and 32 tall.
    "check": (343 - 32, 14, 2, "a check box's label in the dialog, two lines"),
    # UIPanelButtonTemplate, the text 8 in from each side; a row's button is 120 wide unless its row says otherwise.
    "button": (120 - 16, 12, 1, "a button of the dialog"),
    # WowStyle1DropdownTemplate, 225 wide here: its text from 8 in to the arrow, one line.
    "value": (225 - 30, 12, 1, "a dropdown's value, one line"),
    # The Keybindings page's bar: the name from 21 in, the plus or minus on the right.
    "section": (343 - 21 - 30, 12, 1, "a section's bar"),
    # SettingsListElementTemplate's Text: from 37 to the row's middle less 85, of a row 635 wide (the panel's 920,
    # less the list on its left and the margins); no word wrap.
    "page": (195, 12, 1, "an options row's name, one line"),
    "pageButton": (200 - 16, 12, 1, "a button of the options page"),
}

COLLECT = r"""
return function(dev, dialogName)
    local F = FakeWoW
    local ns = _G[dev].ns
    local out = { places = {}, strings = {}, own = ns.StringsFor(GetLocale()) }
    local function place(role, text, width)
        if type(text) == "string" and text ~= "" then
            out.places[#out.places + 1] = { role = role, text = text, width = width or 0 }
        end
    end
    local frame = _G[dialogName]
    for _, bar in ipairs(frame and frame.sections or {}) do
        place("section", bar.section and bar.section.name)
    end
    for _, f in ipairs(frame and frame.rows or {}) do
        local row = f.row
        if row.kind == "check" then
            place("check", row.name)
        else
            place("label", row.name)
        end
        if row.kind == "button" then
            place("button", row.text, row.width)
        end
        local values = row.values
        if type(values) == "function" then
            local ok, list = pcall(values)
            values = ok and list or nil
        end
        for _, v in ipairs(values or {}) do
            place("value", v[2])
        end
    end
    local page = ns.Options and ns.Options.page
    if page and page.category then
        pcall(F.PickSettingsPage, page.category)
        for _, f in ipairs(page.frame and page.frame.rows or {}) do
            if f.row and f.row.kind ~= "header" then
                place("page", f.row.name)
                place("pageButton", f.row.text)
            end
        end
    end
    for locale in pairs(ns.STRINGS) do
        out.strings[locale] = ns.StringsFor(locale)
    end
    out.english = ns.STRINGS.enUS
    out.built = frame ~= nil and #(frame.rows or {}) or 0
    return out
end
"""


class Font:
    """A TrueType file's advance widths, read without a library: the head, hhea, hmtx and cmap tables."""

    def __init__(self, path):
        d = path.read_bytes()
        tables = {}
        for i in range(struct.unpack(">H", d[4:6])[0]):
            tag, _, offset, _ = struct.unpack(">4sIII", d[12 + 16 * i:28 + 16 * i])
            tables[tag.decode("latin-1")] = offset
        self.per_em = struct.unpack(">H", d[tables["head"] + 18:tables["head"] + 20])[0]
        count = struct.unpack(">H", d[tables["hhea"] + 34:tables["hhea"] + 36])[0]
        start = tables["hmtx"]
        self.advances = [struct.unpack(">H", d[start + 4 * i:start + 4 * i + 2])[0] for i in range(count)]
        self.glyphs = self._glyphs(d, tables["cmap"])

    @staticmethod
    def _glyphs(d, base):
        """Character to glyph, from the cmap's format 4 table (Windows' Unicode one when there are several)."""
        best = None
        for i in range(struct.unpack(">H", d[base + 2:base + 4])[0]):
            platform, encoding, offset = struct.unpack(">HHI", d[base + 4 + 8 * i:base + 12 + 8 * i])
            format_4 = struct.unpack(">H", d[base + offset:base + offset + 2])[0] == 4
            if format_4 and (best is None or (platform, encoding) == (3, 1)):
                best = base + offset
        if best is None:
            raise ValueError("no format 4 cmap")
        size = struct.unpack(">H", d[best + 6:best + 8])[0]
        n = size // 2
        ends = struct.unpack(f">{n}H", d[best + 14:best + 14 + size])
        at = best + 16 + size
        starts = struct.unpack(f">{n}H", d[at:at + size])
        deltas = struct.unpack(f">{n}h", d[at + size:at + 2 * size])
        offsets_at = at + 2 * size
        offsets = struct.unpack(f">{n}H", d[offsets_at:offsets_at + size])
        out = {}
        for i in range(n):
            for c in range(starts[i], min(ends[i], 0xFFFE) + 1):
                if offsets[i] == 0:
                    glyph = (c + deltas[i]) & 0xFFFF
                else:
                    p = offsets_at + 2 * i + offsets[i] + 2 * (c - starts[i])
                    glyph = struct.unpack(">H", d[p:p + 2])[0]
                    glyph = (glyph + deltas[i]) & 0xFFFF if glyph else 0
                if glyph:
                    out[c] = glyph
        return out

    def width(self, text, height):
        total = 0
        for ch in text:
            glyph = self.glyphs.get(ord(ch), self.glyphs.get(ord("?"), 0))
            total += self.advances[min(glyph, len(self.advances) - 1)]
        return total * height / self.per_em

    def lines(self, text, height, width, slack=1.0):
        """The lines the game's word wrap makes of a text: a break the text holds is kept, words stay whole."""
        out = []
        for part in text.split("\n"):
            line = ""
            for word in part.split(" "):
                longer = word if not line else line + " " + word
                if line and self.width(longer, height) * slack > width:
                    out.append(line)
                    line = word
                else:
                    line = longer
            out.append(line)
        return out


def font_path():
    return next(iter(sorted(ROOT.glob(f"*/bench/art/{FONT_NAME}"))), None)


def misfit(font, text, room, width=None):
    """Why a text doesn't fit its room, or None: measured as it is, and with every glyph SLACK wider."""
    room_width, height, allowed, _ = room
    room_width = width or room_width
    for slack in (1.0, SLACK):
        lines = font.lines(text, height, room_width, slack)
        widest = max(font.width(line, height) for line in lines)
        if widest * slack > room_width:
            word = max(lines, key=lambda line: font.width(line, height))
            return f'"{word}" is {widest:.0f} wide for {room_width:.0f}'
        if len(lines) > allowed:
            return f"takes {len(lines)} lines of {room_width:.0f} ({' / '.join(lines)})"
    return None


def problems(lua, dev, dialog):
    """(the problems, the line a runner prints) for the dialog named `dialog` and the options page of the addon whose
    development table is `dev`, in the state its smoke session left them: both opened once, so built."""
    path = font_path()
    if not path:
        return [], f"labels: not measured, the game's font ({FONT_NAME}) is in no bench's art folder"
    font = Font(path)
    got = lua.execute(COLLECT)(dev, dialog)
    if not got.built:
        return [f"labels: {dialog} has no rows: the smoke session didn't open it"], "labels: nothing to measure"
    keys = {}
    for key, text in got.own.items():
        if isinstance(text, str):
            keys.setdefault(text, []).append(key)
    locales = sorted(got.strings.keys())
    found, seen, measured = {}, set(), 0
    for i in range(1, len(got.places) + 1):
        place = got.places[i]
        role, french, width = place["role"], place["text"], place["width"]
        room = ROOMS[role]
        for key in keys.get(french, ()):
            if (role, key, width) in seen:
                continue
            seen.add((role, key, width))
            for locale in locales:
                text = got.strings[locale][key]
                if text is None:
                    text = got.english[key]
                if not isinstance(text, str):
                    continue
                measured += 1
                why = misfit(font, text, room, width - 16 if role == "button" and width else None)
                if why:
                    found.setdefault((key, text.replace("\n", "\\n"), why, room[3]), []).append(locale)
    out = [f"labels: {key} in {', '.join(where)}: {why}, as {what}: \"{text}\""
           for (key, text, why, what), where in sorted(found.items())]
    return out, (f"labels: {measured} texts of the dialog and the options page in {len(locales)} languages against "
                 f"their room, {len(out)} that don't fit")
