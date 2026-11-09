-- The rows' own font objects, copied from Blizzard's tracker fonts, so the addon's text size writes nothing to
-- Blizzard's. With no size of its own they follow Blizzard's, which Edit Mode sets. Whichever was changed last wins.
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
    return tostring(file) .. ":" .. tostring(size) .. ":" .. tostring(flags)
end

-- Blizzard's ObjectiveTrackerFont<size> families hold a font for each alphabet, so a size of the addon's own keeps
-- them. Outside 12 to 22 there's none, and the client's font is resized instead. Shadow and justification stay the
-- base's.
local function sized(font, baseFont, size)
    font:SetFontObject(baseFont)
    if not size then
        return
    end
    local family = _G["ObjectiveTrackerFont" .. size]
    if type(family) == "table" and family.GetFont then
        font:SetFontObject(family)
        font:SetShadowOffset(baseFont:GetShadowOffset())
        font:SetShadowColor(baseFont:GetShadowColor())
        font:SetJustifyH(baseFont:GetJustifyH() or "LEFT")
        font:SetJustifyV(baseFont:GetJustifyV() or "TOP")
        return
    end
    local file, _, flags = font:GetFont()
    if file then
        font:SetFont(file, size, flags or "")
    end
end

function Fonts.Apply()
    line = line or CreateFont("KaLiQuestLineFont")
    header = header or CreateFont("KaLiQuestHeaderFont")
    local lineBase = base("ObjectiveTrackerLineFont", "GameFontHighlight")
    local headerBase = base("ObjectiveTrackerHeaderFont", "GameFontNormal")
    local size = ns.db.options.textSize
    local key = keyOf(lineBase) .. "|" .. keyOf(headerBase) .. "|" .. tostring(size)
    if key == appliedKey then
        return
    end
    appliedKey = key
    if lineBase then
        sized(line, lineBase, size)
    end
    if headerBase then
        sized(header, headerBase, size and size + 2)
    end
end

function Fonts.Size()
    local _, size = (line or base("ObjectiveTrackerLineFont", "GameFontHighlight")):GetFont()
    return type(size) == "number" and size > 0 and size or 12
end

-- Edit Mode's text size, for the options page's slider when the addon has none of its own.
function Fonts.EditModeSize()
    local font = base("ObjectiveTrackerLineFont", "GameFontHighlight")
    local _, size = font and font:GetFont()
    return type(size) == "number" and math.floor(size + 0.5) or 12
end

-- Called after Edit Mode sets its text size. A change from the one last seen there clears the addon's own, so the
-- slider moved last is the one that shows. The same value coming back at login changes nothing.
function Fonts.NoteEditMode(size)
    local o = ns.db.options
    if type(size) ~= "number" then
        return
    end
    if o.editModeTextSize ~= nil and o.editModeTextSize ~= size then
        o.textSize = nil
    end
    o.editModeTextSize = size
end
