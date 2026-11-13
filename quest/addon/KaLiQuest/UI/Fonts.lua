-- The rows' own font objects, pointed at Blizzard's tracker font families at its smallest size, 12 for lines and 14
-- for headers: the zoom alone makes the tracker bigger or smaller. Edit Mode's text size no longer applies, since the
-- tracker became an Edit Mode frame of its own (Ikar's choice, 2026-11-13): its dialog, where that size was, is
-- Blizzard's tracker's, which the addon hides. The families pick each alphabet's font. Nothing is written to Blizzard's.
local _, ns = ...

local Fonts = {}
ns.Fonts = Fonts

Fonts.LINE_SIZE = 12

local line, header
local applied = false

local function base(name, fallback)
    local font = _G[name]
    if font and font.GetFont then
        return font
    end
    return _G[fallback]
end

-- What Blizzard's ObjectiveTrackerLineFont and ObjectiveTrackerHeaderFont add to the families: their shadow, their
-- justification and, for headers, the gold.
local function finish(font)
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0)
    font:SetJustifyH("LEFT")
    font:SetJustifyV("TOP")
end

-- Only ever pointed at Blizzard's fonts: in game, a size set on them directly stuck through later changes.
function Fonts.Apply()
    if applied then
        return
    end
    applied = true
    line = line or CreateFont("KaLiQuestLineFont")
    header = header or CreateFont("KaLiQuestHeaderFont")
    line:SetFontObject(base("ObjectiveTrackerFont" .. Fonts.LINE_SIZE, "GameFontHighlight"))
    header:SetFontObject(base("ObjectiveTrackerFont" .. (Fonts.LINE_SIZE + 2), "GameFontNormal"))
    finish(line)
    finish(header)
    local gold = NORMAL_FONT_COLOR
    if gold and gold.GetRGB then
        header:SetTextColor(gold:GetRGB())
    end
end

function Fonts.Size()
    local _, size = (line or base("ObjectiveTrackerFont" .. Fonts.LINE_SIZE, "GameFontHighlight")):GetFont()
    return type(size) == "number" and size > 0 and size or Fonts.LINE_SIZE
end
