-- Other addons' minimap buttons, gathered into the slot hub (Ikar 2026-11-14): LibDBIcon's are put away, their LDB
-- object being one of the hub's elements already; the others become elements of their own, their art as the addon
-- draws it, at the icon size, wherever they're put (a folder by default). A button its addon hides takes no place.
local _, ns = ...

local Collect = {}
ns.Collect = Collect

local Hub = ns.Hub

-- Button-sized: what a frame on the map must be, across and up, to be taken for a button.
local SMALLEST, LARGEST = 12, 48
-- The common minimap button's ring and the dark disc behind its icon (MiniMap-TrackingBorder, UI-Minimap-Background):
-- out of sight while held, its icon on nothing at the icon size, as ours (Ikar 2026-11-14).
local FRAME_ART = { [136430] = true, [136467] = true }
local FRAME_FILES = { "minimap%-trackingborder", "ui%-minimap%-background" }
local TAILS = {
    "[Mm]ini[Mm]ap[Bb]utton$", "[Mm]ap[Ii]con$", "[Mm]ini[Mm]ap$", "[Ii]con[Ff]rame$", "[Bb]utton$", "[Ii]con$",
}

local frames, names, kept, objects = {}, {}, {}, {}
local hooked = setmetatable({}, { __mode = "k" })
-- where LibDBIcon's buttons and hidden elements go: a frame never shown
local away
-- the frame we're moving, which its SetPoint hook lets be
local moving
-- Those whose frame raised an error as it was placed, put away or given back, for the rest of the session: such a
-- frame is another addon's, and what it lets itself be asked isn't ours to know. It takes no place in the hub (Shown
-- answers no), so the bar is laid out without it; its error took the whole bar's layout with it, as one element
-- failing to draw did before (the review of 2026-11-18).
local refused = {}
-- The buttons put away as their object's twin (below), by name, to give back while the hub shows that object nowhere.
local twins = {}
local giveBack

local function holder()
    if not away then
        away = CreateFrame("Frame", nil, UIParent)
        away:Hide()
    end
    return away
end

local function library(major)
    local stub = LibStub
    return type(stub) == "table" and ns.Call(stub.GetLibrary, stub, major, true) or nil
end

-- A frame another addon made into a button on the map: named and its own (the game's are secure), clickable,
-- button-sized. Pins (numbered), LibDBIcon's (put away) and ours are left alone.
local function isButton(f)
    -- A forbidden frame (a nameplate's, the game's own secrets) answers nothing but that it is one: asked first.
    if type(f) ~= "table" or not f.IsForbidden or f:IsForbidden() then
        return false
    end
    local name = f.GetName and f:GetName()
    if type(name) ~= "string" or name:find("^LibDBIcon10_") or name:find("^KaLiHUD") or name:find("%d$") then
        return false
    end
    if issecurevariable(_G, name) or f:IsProtected() or not f:IsMouseEnabled() then
        return false
    end
    local w, h = f:GetWidth(), f:GetHeight()
    return w >= SMALLEST and h >= SMALLEST and w <= LARGEST and h <= LARGEST
end

-- A name a player reads: the frame's, without what says it's a button on the map.
local function readable(name)
    local s = name
    for _, tail in ipairs(TAILS) do
        s = s:gsub("[_%-]?" .. tail, "")
    end
    s = s:gsub("[_%-]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s ~= "" and s or name
end

local function squash(s)
    return (s:lower():gsub("%W", ""))
end

-- The button of an addon that has a LibDataBroker object of the same name too (KaLi Recipe's): that object is one of
-- the hub's elements already. The object's name, nil with none.
local function twin(name)
    local ldb = library("LibDataBroker-1.1")
    if not (ldb and ldb.DataObjectIterator) then
        return nil
    end
    local key = squash(readable(name))
    for objName in ldb.DataObjectIterator(ldb) do
        if type(objName) == "string" and squash(objName) == key then
            return objName
        end
    end
    return nil
end

local function frameArt(t)
    local id, path = t:GetTextureFileID(), t:GetTextureFilePath()
    if FRAME_ART[id] or FRAME_ART[path] then
        return true
    end
    if type(path) == "string" then
        path = path:lower()
        for _, file in ipairs(FRAME_FILES) do
            if path:find(file) then
                return true
            end
        end
    end
    return false
end

-- Its frame art put out of sight; its icon, the largest texture left: its size, how far its centre is off the button's
-- (in the button's units), and the clicks taken on it alone, as the button grows round it.
local function art(k, f)
    local icon, area = nil, 0
    k.hidden = {}
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetDrawLayer() ~= "HIGHLIGHT" then
            if frameArt(r) then
                k.hidden[#k.hidden + 1] = { r, r:GetAlpha() }
                r:SetAlpha(0)
            elseif r:GetWidth() * r:GetHeight() > area then
                icon, area = r, r:GetWidth() * r:GetHeight()
            end
        end
    end
    k.size, k.ox, k.oy = 0, 0, 0
    k.insets = { f:GetHitRectInsets() }
    if not icon then
        return
    end
    local iw, ih = icon:GetWidth(), icon:GetHeight()
    k.size = math.max(iw, ih)
    local fx, fy = f:GetCenter()
    local ix, iy = icon:GetCenter()
    if fx and ix then
        k.ox, k.oy = ix - fx, iy - fy
    end
    local w, h = f:GetWidth() / 2, f:GetHeight() / 2
    f:SetHitRectInsets(math.max(0, w + k.ox - iw / 2), math.max(0, w - k.ox - iw / 2), math.max(0, h - k.oy - ih / 2),
        math.max(0, h + k.oy - ih / 2))
end

-- The game ignores both on a button that fixed them (KaLi Recipe's, LibDBIcon's), which then stood under the list.
local function layer(f, strata, level)
    if f:GetFrameStrata() == strata and f:GetFrameLevel() == level then
        return
    end
    local fixedStrata, fixedLevel = f:HasFixedFrameStrata(), f:HasFixedFrameLevel()
    if fixedStrata then
        f:SetFixedFrameStrata(false)
    end
    if fixedLevel then
        f:SetFixedFrameLevel(false)
    end
    f:SetFrameStrata(strata)
    f:SetFrameLevel(level)
    if fixedStrata then
        f:SetFixedFrameStrata(true)
    end
    if fixedLevel then
        f:SetFixedFrameLevel(true)
    end
end

-- Its addon showing or hiding it: it takes a place again, or gives it up. Hooked on another addon's frame, as those
-- below: each under the handlers' guard (ns.Guarded).
local shownChanged = ns.Guarded(function(self)
    local k = kept[self:GetName()]
    if k and k.shown ~= self:IsShown() then
        k.shown = self:IsShown()
        ns.InfoBar.Request()
    end
end)

-- How a button was before we took it, to give it back; the addon moving or dragging it round the map puts it back
-- where the hub has it, its tooltip gets the hub's hints; its clicks stay its addon's.
local function keep(name, f)
    if kept[name] then
        return
    end
    local points = {}
    for i = 1, f:GetNumPoints() do
        points[i] = { f:GetPoint(i) }
    end
    kept[name] = { parent = f:GetParent(), scale = f:GetScale(), strata = f:GetFrameStrata(), level = f:GetFrameLevel(),
        alpha = f:GetAlpha(), mouse = f:IsMouseEnabled(), points = points, shown = f:IsShown(),
        dragged = f:GetScript("OnDragStart") ~= nil }
    art(kept[name], f)
    f:RegisterForDrag()
    if hooked[f] then
        return
    end
    hooked[f] = true
    hooksecurefunc(f, "SetPoint", ns.Guarded(function(self)
        local at = kept[name] and kept[name].at
        if moving ~= self and at and at.x then
            Collect.Place(name, at.parent, at.x, at.y, at.shown)
        end
    end))
    -- Its clicks are its addon's, the right one too (Ikar 2026-11-17, one right-click): the padlock open, the handle
    -- over it takes them (UI/Hub/Buttons.lua), its hub menu on the right one.
    f:HookScript("OnEnter", ns.Guarded(function(self)
        if kept[name] and GameTooltip:IsOwned(self) then
            ns.HubMenus.AddHints(GameTooltip, name)
            GameTooltip:Show()
        end
    end))
    -- what its click opens takes its tooltip away, as our buttons' click does (UI/Hub/Buttons.lua's onClick); a frame
    -- with no click script (a plain Frame) has none to hook
    if f.HasScript and f:HasScript("OnClick") then
        f:HookScript("OnClick", ns.Guarded(function(self)
            if kept[name] and GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end))
    end
    -- one round the map seen on hover stays while the pointer is on it
    f:HookScript("OnLeave", function()
        if kept[name] then
            ns.SafeCall(ns.Minimap.UpdateHover)
        end
    end)
    f:HookScript("OnShow", shownChanged)
    f:HookScript("OnHide", shownChanged)
end

-- The hub's element for one of LibDBIcon's buttons: its LDB object's (the button holds it), which the library lets
-- an addon name otherwise than the button; else the element of the button's own name.
local function iconEntry(name, b)
    local obj = b.dataObject
    if type(obj) == "table" then
        for _, e in ipairs(Hub.Entries()) do
            if e.obj == obj then
                return e
            end
        end
    end
    return Hub.Entry(name)
end

-- A button whose object is the hub's element in its place (`e`, nil with none): put away while the hub has that
-- object, which it shows or the player hid there; back on the map, as its addon had it, while the hub shows that
-- object nowhere (the info bar off, the object on it) or has none for it. Where each was is kept, to put it back.
local homes = setmetatable({}, { __mode = "k" })
local function awayOrBack(b, e)
    local away = e ~= nil and not ns.InfoBar.OffBar(e)
    local parent = b:GetParent()
    if away and parent ~= holder() then
        homes[b] = { parent = parent, strata = b:GetFrameStrata(), level = b:GetFrameLevel() }
        b:SetParent(holder())
    elseif not away and parent == holder() then
        local home = homes[b]
        b:SetParent(home and home.parent or _G.Minimap)
        if home then
            layer(b, home.strata, home.level)
        end
    end
end

-- LibDBIcon's buttons, whose object the hub has, and the twins (a button put away for its addon's object of the same
-- name): away or back as the hub shows their object or not (awayOrBack), each on its own. A twin stayed away with the
-- info bar off, its object shown nowhere: its addon out of reach (the review of 2026-11-18).
function Collect.SyncIcons()
    if not ns.db then
        return
    end
    local dbi = library("LibDBIcon-1.0")
    for _, name in ipairs(dbi and ns.Call(dbi.GetButtonList, dbi) or {}) do
        local b = ns.Call(dbi.GetMinimapButton, dbi, name)
        if type(b) == "table" and b.GetParent then
            ns.SafeCall(awayOrBack, b, iconEntry(name, b))
        end
    end
    for name, f in pairs(twins) do
        local object = twin(name)
        ns.SafeCall(awayOrBack, f, object and Hub.Entry(object) or nil)
    end
end

-- How many children a frame may have to be asked for them all in one call. GetChildren hands every one back at once,
-- and the game's Lua holds about 8000 values: on a map crowded with another addon's pins it erred "stack overflow"
-- (Ikar 2026-11-22, eight times since 2026-11-19). Past this, the map's own frames are found among all the game's.
local MOST_CHILDREN = 2000

-- fn(child) for each child frame of parent.
local function eachChild(parent, fn)
    local count = parent.GetNumChildren and parent:GetNumChildren() or 0
    if count <= MOST_CHILDREN then
        for _, f in ipairs({ parent:GetChildren() }) do
            fn(f)
        end
        return
    end
    local f = EnumerateFrames()
    while f do
        -- a forbidden frame answers nothing but that it is one (isButton)
        if not f:IsForbidden() and f:GetParent() == parent then
            fn(f)
        end
        f = EnumerateFrames(f)
    end
end

-- Looks for buttons: LibDBIcon's put away, new ones of other addons taken.
function Collect.Scan()
    Collect.SyncIcons()
    local changed = false
    -- one taken whose addon made its object since: given back as it was, then put away as that object's twin
    for i = #names, 1, -1 do
        local name = names[i]
        local object = twin(name)
        if object then
            local f = frames[name]
            ns.SafeCall(giveBack, name)
            frames[name] = nil
            table.remove(names, i)
            twins[name] = f
            ns.SafeCall(awayOrBack, f, Hub.Entry(object))
            changed = true
        end
    end
    for _, parent in ipairs({ _G.Minimap, _G.MinimapBackdrop }) do
        if type(parent) == "table" and parent.GetChildren then
            eachChild(parent, function(f)
                local name = isButton(f) and f:GetName()
                if name and not frames[name] and not ns.db.buttonsLeft[name] then
                    local object = twin(name)
                    if object then
                        twins[name] = f
                        ns.SafeCall(awayOrBack, f, Hub.Entry(object))
                    else
                        -- a twin whose object is gone is a button of its own again
                        twins[name] = nil
                        frames[name] = f
                        names[#names + 1] = name
                        changed = true
                    end
                end
            end)
        end
    end
    if changed then
        table.sort(names, ns.TextLess)
        Hub.Changed()
    end
end

-- How long after an addon loads its button is looked for again: some make theirs a moment later.
local LATE = 2

-- At login, and again as late addons make their buttons: after the login's own scans, an addon loaded on demand made
-- its button unseen, left on the map until the next login (the review of 2026-11-17). Each addon that loads has the
-- map looked at on the next frame and once more a moment later, however many load together (LibDBIcon's buttons too,
-- which each scan reads from the library); nothing is scanned at intervals.
function Collect.Start()
    local dbi = library("LibDBIcon-1.0")
    if dbi and type(dbi.RegisterCallback) == "function" then
        ns.Call(dbi.RegisterCallback, Collect, "LibDBIcon_IconCreated", function()
            ns.Later("collect", Collect.Scan)
        end)
    end
    Collect.Scan()
    for _, delay in ipairs({ 2, 8 }) do
        C_Timer.After(delay, function()
            ns.SafeCall(Collect.Scan)
        end)
    end
    local waiting = false
    ns.On("ADDON_LOADED", function()
        ns.Later("collect", Collect.Scan)
        if not waiting then
            waiting = true
            C_Timer.After(LATE, function()
                waiting = false
                ns.SafeCall(Collect.Scan)
            end)
        end
    end)
end

-- The buttons taken, by name: read it, never change it.
function Collect.List()
    return names
end

function Collect.Frame(name)
    return frames[name]
end

-- Whether its addon shows it: one it hides takes no place, nor one whose frame refused to be placed (refused).
function Collect.Shown(name)
    local f = frames[name]
    return f ~= nil and not refused[name] and f:IsShown()
end

-- A button whose frame raised an error under our hands: the error is kept (ns.SafeCall), the button given back to
-- its addon as far as it lets itself be (`given`: that's what failed), and the hub laid out again without it.
local function refuse(name, given)
    moving = nil
    refused[name] = true
    if not given then
        ns.SafeCall(giveBack, name)
    end
    kept[name] = nil
    ns.HubButtons.PlaceHandle(name, nil)
    ns.InfoBar.Request()
end

function Collect.Object(name)
    local o = objects[name]
    if not o then
        o = { label = readable(name), foreign = true }
        objects[name] = o
    end
    return o
end

-- Puts name's button, its centre at (ux, uy) in UIParent's units, in `parent` (UIParent by default) at the icon
-- size; shown unless `shown` is false (round the map, one seen on hover).
local function place(name, f, parent, ux, uy, shown)
    keep(name, f)
    moving = f
    if f:GetParent() ~= parent then
        f:SetParent(parent)
    end
    local k = kept[name]
    local big = k.size > 0 and k.size or math.max(f:GetWidth(), f:GetHeight())
    f:SetScale(big > 0 and Hub.IconSize() / big or 1)
    layer(f, parent == UIParent and "MEDIUM" or parent:GetFrameStrata(), parent == UIParent and 18 or parent:GetFrameLevel() + 5)
    local s = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux * s - k.ox, uy * s - k.oy)
    moving = nil
    f:SetAlpha(shown and 1 or 0)
    f:EnableMouse(shown and k.mouse or false)
    local at = k.at or {}
    at.parent, at.x, at.y, at.shown = parent, ux, uy, shown
    k.at = at
    ns.HubButtons.PlaceHandle(name, ux, uy, Hub.IconSize() + 4, true)
end

function Collect.Place(name, parent, ux, uy, shown)
    local f = frames[name]
    if not f or refused[name] then
        return
    end
    if not ns.SafeCall(place, name, f, parent or UIParent, ux, uy, shown ~= false) then
        refuse(name)
    end
end

-- Shown or not where it stands: round the map, one seen on hover.
function Collect.SetShown(name, shown)
    local at = kept[name] and kept[name].at
    if at and at.x and at.shown ~= shown then
        Collect.Place(name, at.parent, at.x, at.y, shown)
    end
end

-- Under the pointer while dragged by its handle.
function Collect.Follow(name, ux, uy)
    local f = frames[name]
    if not f then
        return
    end
    local k = kept[name]
    local s = UIParent:GetEffectiveScale() / f:GetEffectiveScale()
    moving = f
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux * s - (k and k.ox or 0), uy * s - (k and k.oy or 0))
    moving = nil
end

local function hide(name, f)
    keep(name, f)
    local at = kept[name].at
    if at then
        at.x = nil
    end
    if f:GetParent() ~= holder() then
        f:SetParent(holder())
    end
    ns.HubButtons.PlaceHandle(name, nil)
end

-- Hidden: put away, so its addon showing it doesn't bring it back.
function Collect.Hide(name)
    local f = frames[name]
    if not f or refused[name] then
        return
    end
    if not ns.SafeCall(hide, name, f) then
        refuse(name)
    end
end

-- Given back to its addon as it was before it was taken (parent, size, layer, art, clicks, place, drag); taken again
-- as it is then, the next time it's placed.
function giveBack(name)
    local f, k = frames[name], kept[name]
    if f and k then
        kept[name] = nil
        f:SetParent(k.parent)
        f:SetScale(k.scale or 1)
        layer(f, k.strata or "MEDIUM", k.level or f:GetFrameLevel())
        for _, hidden in ipairs(k.hidden) do
            hidden[1]:SetAlpha(hidden[2])
        end
        f:SetHitRectInsets(unpack(k.insets))
        f:SetAlpha(k.alpha or 1)
        f:EnableMouse(k.mouse ~= false)
        f:ClearAllPoints()
        for _, point in ipairs(k.points) do
            f:SetPoint(unpack(point))
        end
        -- dragged round the map by its addon: the left button, as LibDBIcon's and most register it (it can't be read)
        if k.dragged then
            f:RegisterForDrag("LeftButton")
        end
    end
    ns.HubButtons.PlaceHandle(name, nil)
end

-- Set round a map that isn't ours (Ikar 2026-11-15): back to its addon on the map, until the map is ours again.
function Collect.GiveBack(name)
    if not refused[name] and not ns.SafeCall(giveBack, name) then
        refuse(name, true)
    end
end

-- Not a button for the hub after all: given back to its addon as it was, never taken again until taken back.
function Collect.Leave(name)
    ns.db.buttonsLeft[name] = true
    Hub.Unplace(name)
    Collect.GiveBack(name)
    refused[name] = nil
    frames[name] = nil
    for i, n in ipairs(names) do
        if n == name then
            table.remove(names, i)
            break
        end
    end
    Hub.Changed()
end

function Collect.TakeBack(name)
    ns.db.buttonsLeft[name] = nil
    Collect.Scan()
    Hub.Changed()
end
