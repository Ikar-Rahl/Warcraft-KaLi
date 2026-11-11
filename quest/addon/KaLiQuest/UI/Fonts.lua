-- The rows' own font objects, following Blizzard's tracker fonts, whose size Edit Mode's text size sets. Nothing is
-- written to Blizzard's. The zoom, not these, makes the whole tracker bigger or smaller.
local _, ns = ...

local Fonts = {}
ns.Fonts = Fonts

local line, header
local appliedKey -- what the fonts were last made from, so a redraw that changes nothing leaves them alone

local function base(name, fallback)
    local font = _G[name]
    if font and font.GetFont then
        return font
    end
    return _G[fallback]
end

local function keyOf(font)
    if not font then
        return "-"
    end
    local file, size, flags = font:GetFont()
    return tostring(font) .. ":" .. tostring(file) .. ":" .. tostring(size) .. ":" .. tostring(flags)
end

-- Only ever pointed at Blizzard's fonts: in game, a size set on them directly stuck through later changes.
function Fonts.Apply()
    line = line or CreateFont("KaLiQuestLineFont")
    header = header or CreateFont("KaLiQuestHeaderFont")
    local lineBase = base("ObjectiveTrackerLineFont", "GameFontHighlight")
    local headerBase = base("ObjectiveTrackerHeaderFont", "GameFontNormal")
    local key = keyOf(lineBase) .. "|" .. keyOf(headerBase)
    if key == appliedKey then
        return
    end
    appliedKey = key
    if lineBase then
        line:SetFontObject(lineBase)
    end
    if headerBase then
        header:SetFontObject(headerBase)
    end
end

function Fonts.Size()
    local _, size = (line or base("ObjectiveTrackerLineFont", "GameFontHighlight")):GetFont()
    return type(size) == "number" and size > 0 and size or 12
end
