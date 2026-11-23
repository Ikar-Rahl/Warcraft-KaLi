-- The game's frames: those the plate may take, read in UIParent's units (only read: Edit Mode, the game or the player
-- moves them, and the plate follows); and those the HUD does change (the minimap's widgets and dressing), kept as they
-- were to be given back.
local _, ns = ...

local Frames = {}
ns.Frames = Frames

-- What the plate takes, by global name, with its kind and margin group: the bars, the chat and the damage meter,
-- and the minimap, which gets the dome. One this client hasn't is skipped. MainActionBar is the main bar's name since
-- 11.0, MainMenuBar's before; its page switch stays outside the measured rect so stacked bars remain aligned.
Frames.ACCEPTED = {
    { "MainActionBar", "bar", "bars" }, { "MainMenuBar", "bar", "bars" },
    { "MultiBarBottomLeft", "bar", "bars" }, { "MultiBarBottomRight", "bar", "bars" },
    { "MultiBarRight", "bar", "bars" }, { "MultiBarLeft", "bar", "bars" },
    { "MultiBar5", "bar", "bars" }, { "MultiBar6", "bar", "bars" }, { "MultiBar7", "bar", "bars" },
    { "StanceBar", "bar", "bars" }, { "PetActionBar", "bar", "bars" }, { "MultiCastActionBarFrame", "bar", "bars" },
    { "MicroMenuContainer", "bar", "bags" }, { "BagsBar", "bar", "bags" },
    { "ChatFrame1", "window", "chat" }, { "DamageMeter", "window", "meter" },
    { "MinimapCluster", "minimap", "dome" },
}

-- A frame Edit Mode moves: registered as one of its systems.
function Frames.IsSystem(f)
    return type(f) == "table" and f.system ~= nil and type(f.OnSystemPositionChange) == "function"
end

function Frames.Get(name)
    local f = type(name) == "string" and _G[name]
    return Frames.IsSystem(f) and f or nil
end

-- How many UIParent units one unit of the frame is.
local function scaleOf(f)
    return f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- A region's rectangle in UIParent's units: left, bottom, width, height; nil while it has none (hidden).
function Frames.Rect(f)
    if type(f) ~= "table" or not f.GetRect then
        return nil
    end
    local left, bottom, width, height = f:GetRect()
    if not left then
        return nil
    end
    local k = scaleOf(f)
    return left * k, bottom * k, width * k, height * k
end

-- How far a part may be from its frame and still belong to it: FlareUI parks Blizzard's tab dock at -10000.
local NEAR = 64

local function nearSpan(x, y, w, h, px, py, pw, ph)
    return px < x + w + NEAR and px + pw > x - NEAR and py < y + h + NEAR and py + ph > y - NEAR
end

local function unionPart(x0, y0, x1, y1, bx, by, bw, bh, part)
    if type(part) == "table" and part.IsShown and part:IsShown() then
        local px, py, pw, ph = Frames.Rect(part)
        if px and nearSpan(bx, by, bw, bh, px, py, pw, ph) then
            return math.min(x0, px), math.min(y0, py), math.max(x1, px + pw), math.max(y1, py + ph)
        end
    end
    return x0, y0, x1, y1
end

-- BagsBar's GetRect always includes all bag slots even when collapsed. The bags always fold (Ikar 2026-11-15: no
-- option): only the backpack and its toggle arrow count, so neither a collapsed bar nor temporarily extending the bags
-- grows a chimney on the HUD.
local function bagsSpan(f)
    local backpack = _G.MainMenuBarBackpackButton
    if not (type(backpack) == "table" and backpack.IsShown and backpack:IsShown()) then
        return Frames.Rect(f)
    end
    local bx, by, bw, bh = Frames.Rect(backpack)
    if not bx then
        return Frames.Rect(f)
    end
    local x0, y0, x1, y1 = bx, by, bx + bw, by + bh
    -- the backpack and the arrow that folds the bags (ours, FlareUI's or Blizzard's), never the bags unfolded
    x0, y0, x1, y1 = unionPart(x0, y0, x1, y1, bx, by, bw, bh, _G.KaLiHUD_BagBarToggle)
    x0, y0, x1, y1 = unionPart(x0, y0, x1, y1, bx, by, bw, bh, _G.FlareUI_BagBarToggle)
    x0, y0, x1, y1 = unionPart(x0, y0, x1, y1, bx, by, bw, bh, _G.BagBarExpandToggle)
    return x0, y0, x1 - x0, y1 - y0
end

-- Allocation-free span (x, y, w, h) in UIParent's units, for live drag checks and box queries.
-- The chat as it shows: ChatFrame1, or the window docked with it whose tab is picked (the dock hides the others).
local function shownChat(f)
    local dock = _G.GENERAL_CHAT_DOCK
    local picked = not f:IsShown() and type(dock) == "table" and dock.primary == f and dock.selected
    return type(picked) == "table" and picked or f
end

local SPAN = {
    ChatFrame1 = function(f)
        f = shownChat(f)
        local bx, by, bw, bh = Frames.Rect(f)
        if not bx then
            return nil
        end
        local x0, y0, x1, y1 = bx, by, bx + bw, by + bh
        x0, y0, x1, y1 = unionPart(x0, y0, x1, y1, bx, by, bw, bh, f.FlareUI_Skin)
        x0, y0, x1, y1 = unionPart(x0, y0, x1, y1, bx, by, bw, bh, f.buttonFrame)
        x0, y0, x1, y1 = unionPart(x0, y0, x1, y1, bx, by, bw, bh, _G.GeneralDockManager)
        return x0, y0, x1 - x0, y1 - y0
    end,
    DamageMeter = function(f)
        local bx, by, bw, bh = Frames.Rect(f)
        if not bx then
            return nil
        end
        local window = _G.DamageMeterSessionWindow1
        local x0, y0, x1, y1 = unionPart(bx, by, bx + bw, by + bh, bx, by, bw, bh, window and window.FlareUI_DMSkin)
        return x0, y0, x1 - x0, y1 - y0
    end,
    BagsBar = bagsSpan,
    MinimapCluster = function()
        return Frames.Rect(_G.Minimap)
    end,
}

function Frames.Span(name)
    local f = Frames.Get(name)
    if not f then
        return nil
    end
    local fn = SPAN[name]
    if fn then
        return fn(f)
    end
    return Frames.Rect(f)
end

-- What shows of a frame the plate takes: for the chat, the window docked with it whose tab is picked.
function Frames.Shown(name)
    local f = Frames.Get(name)
    if f and name == "ChatFrame1" then
        return shownChat(f)
    end
    return f
end

function Frames.IsEditing()
    local m = _G.EditModeManagerFrame
    return type(m) == "table" and m.IsEditModeActive and m:IsEditModeActive() == true
end

-- ---------- The game's frames the HUD changes ----------

-- How `frame` (a frame or a texture) was the first time it's kept under `key` in `store`: its alpha and mouse; with
-- place, also its parent, scale, layer, size and anchors, kept the first time place is asked for.
function Frames.Keep(store, key, frame, place)
    local was = store[key]
    if not was then
        was = { frame = frame, alpha = frame:GetAlpha(), mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() }
        store[key] = was
    end
    if place and not was.points then
        local points = {}
        for i = 1, frame:GetNumPoints() do
            points[i] = { frame:GetPoint(i) }
        end
        was.points, was.parent, was.scale = points, frame:GetParent(), frame:GetScale()
        was.strata, was.level = frame:GetFrameStrata(), frame:GetFrameLevel()
        was.width, was.height = frame:GetWidth(), frame:GetHeight()
    end
    return was
end

-- Out of sight (no alpha, deaf to the mouse), or seen again as it was kept.
function Frames.SetHidden(store, key, frame, hide)
    if type(frame) ~= "table" then
        return
    end
    local was = Frames.Keep(store, key, frame)
    if hide then
        frame:SetAlpha(0)
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
    else
        frame:SetAlpha(was.alpha)
        if was.mouse ~= nil then
            frame:EnableMouse(was.mouse)
        end
    end
end

-- What was kept under `key` put back, then forgotten: kept again, the frame is taken as it is then.
function Frames.GiveBack(store, key)
    local was = store[key]
    if not was then
        return
    end
    store[key] = nil
    local f = was.frame
    if was.points then
        if f:GetParent() ~= was.parent then
            f:SetParent(was.parent)
        end
        f:SetScale(was.scale)
        f:SetFrameStrata(was.strata)
        f:SetFrameLevel(was.level)
        f:SetSize(was.width, was.height)
        f:ClearAllPoints()
        for _, point in ipairs(was.points) do
            f:SetPoint(unpack(point))
        end
    end
    f:SetAlpha(was.alpha)
    if was.mouse ~= nil then
        f:EnableMouse(was.mouse)
    end
end
