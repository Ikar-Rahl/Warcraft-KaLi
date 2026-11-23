-- Dragging the slot hub's elements while unlocked: the element itself follows the pointer (our button, or a
-- Blizzard widget or another addon's map button with the handle over it), the places it can go light up and a marker
-- shows where it lands: anywhere along the bar, among the items at one of its ends up to LOCK_ZONE past them, on the
-- ring but its bottom arc (the zone's), in a pocket's places, in a folder. Off them, it goes back. Never in a fight:
-- the folders' and macros' buttons are secure, and the bar holds still then (UI/Hub/InfoBar.lua); one going on as a
-- fight starts goes back.
local _, ns = ...

local Drag = {}
ns.HubDrag = Drag

local Hub, Buttons, Geometry = ns.Hub, ns.HubButtons, ns.Geometry
local abs, max, min, sqrt = math.abs, math.max, math.min, math.sqrt

-- How far past the items at the bar's ends a drop joins them; elsewhere it stays where it's dropped.
local LOCK_ZONE = 40
-- The drop zones and the marker.
local LIT = { 1, 1, 1 }
local POCKETS, ENDS, NONE = { "pocketLeft", "pocketRight" }, { "left", "right" }, { pocketLeft = {}, pocketRight = {} }

local dragging, dragFrame, watcher
local zones, markLine, markSlot
-- What drops are read against, taken again whenever the bar is laid out anew or another element is dragged: the
-- bar's top and whether it shows, the dome and its pockets' places, the bar's ends and the items at them ({ x, w } as
-- InfoBar placed them), the block below the map; the one dragged left out.
local ctx = { atEnd = { left = {}, right = {} } }
-- Target's answer, one table for all: read it at once.
local hit = {}

function Drag.Current()
    return dragging
end

local function context()
    local version = ns.InfoBar.Version()
    if ctx.version == version and ctx.dragging == dragging then
        return ctx
    end
    ctx.version, ctx.dragging = version, dragging
    ctx.T, ctx.bar = ns.InfoBar.Top(), ns.db.options.infoBar
    ctx.dome, ctx.onPlate = ns.Minimap.Dome()
    ctx.spots = ctx.dome and ctx.onPlate and Hub.PocketSpots(ctx.dome, ctx.T) or NONE
    ctx.ends, ctx.centre = ns.InfoBar.Ends(), ns.InfoBar.Centre()
    local atEnd = ctx.atEnd
    for _, side in ipairs(ENDS) do
        wipe(atEnd[side])
    end
    for _, e in ipairs(Hub.Entries()) do
        if e.name ~= dragging and atEnd[e.side] then
            atEnd[e.side][#atEnd[e.side] + 1] = ns.InfoBar.Placed(e.name)
        end
    end
    return ctx
end

local function answer(side, kind, x, y, index)
    hit.side, hit.kind, hit.x, hit.y, hit.index = side, kind, x, y, index
    hit.angle, hit.pos, hit.folder, hit.w, hit.h = nil, nil, nil, nil, nil
    return hit
end

-- Where a drop at (ux, uy), in UIParent's units, lands: { side, index or angle or pos or folder, x, y, kind }, the
-- marker at x, y (kind "slot": a round place, "line": on the bar); nil off the places. The answer is reused: read it
-- at once.
function Drag.Target(ux, uy)
    local folder = ns.Folders.DropTarget(ux, uy, dragging)
    if folder then
        return folder
    end
    -- a separator goes into folders only
    if ns.Separators.IsId(dragging) then
        return nil
    end
    local c = context()
    local T, d = c.T, c.dome
    if d and uy > T + 3 then
        local near = Hub.PocketSize() / 2 + 4
        for _, side in ipairs(POCKETS) do
            local spots = c.spots[side]
            for i = 1, #spots do
                local x, y = Hub.PocketPoint(d, spots, side, i)
                if abs(ux - x) <= near and abs(uy - y) <= near then
                    -- any place, free or not (Ikar 2026-11-16): the element there goes where the dragged one stood
                    return answer(side, "slot", x, y, i)
                end
            end
        end
        if sqrt((ux - d.cx) ^ 2 + (uy - d.cy) ^ 2) <= d.r + 48 then
            local angle = Geometry.Angle(d.cx, d.cy, ux, uy)
            local x, y = Geometry.Polar(d.cx, d.cy, Hub.PinRadius(d), angle)
            local half, span = Hub.RING_STEP / 2, c.centre
            -- the ring's bottom arc is the zone's, below the map
            if not (span and y - half < T and x + half > span.x0 and x - half < span.x1) then
                local t = answer("ring", "slot", x, y)
                t.angle = angle
                return t
            end
        end
    end
    -- the bar while it shows, but the zone's block below the map, which is reserved
    if not c.bar or uy > T + 28 then
        return nil
    end
    local span = c.centre
    if span and ux >= span.x0 and ux <= span.x1 then
        return nil
    end
    -- among the items at an end, up to LOCK_ZONE past them, it joins them; anywhere else it stays where it's dropped
    local ends, spacing = c.ends, ns.Hub.Spacing()
    for _, side in ipairs(ENDS) do
        local dir = side == "left" and 1 or -1
        if (ends[side] + dir * LOCK_ZONE - ux) * dir >= 0 then
            local index, mark = 1, side == "left" and ends.leftEdge or ends.rightEdge
            for _, p in ipairs(c.atEnd[side]) do
                if (ux - p.x) * dir > 0 then
                    index = index + 1
                    mark = p.x + dir * (p.w + spacing) / 2
                end
            end
            return answer(side, "line", mark, T / 2, index)
        end
    end
    local t = answer("free", "line", ux, T / 2)
    t.pos = ux / UIParent:GetWidth()
    return t
end

-- ---------- What lights up ----------

local function ensureZones()
    if zones then
        return zones
    end
    zones = CreateFrame("Frame", nil, nil)
    zones:SetParent(UIParent)
    zones:SetAllPoints(UIParent)
    -- over the folders' lists
    zones:SetFrameStrata("DIALOG")
    zones:EnableMouse(false)
    -- the bar either side of the zone's block, and its two ends
    zones.Bar, zones.Ends, zones.Pockets = {}, {}, {}
    for i = 1, 2 do
        local t = zones:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(LIT[1], LIT[2], LIT[3], 0.07)
        zones.Bar[i] = t
        local e = zones:CreateTexture(nil, "BORDER")
        e:SetColorTexture(LIT[1], LIT[2], LIT[3], 0.32)
        zones.Ends[i] = e
    end
    zones.Ring = zones:CreateTexture(nil, "BACKGROUND")
    zones.Ring:SetTexture(ns.RING)
    zones.Ring:SetVertexColor(LIT[1], LIT[2], LIT[3], 0.35)
    markLine = zones:CreateTexture(nil, "OVERLAY")
    markLine:SetColorTexture(LIT[1], LIT[2], LIT[3], 0.95)
    markSlot = CreateFrame("Frame", nil, zones)
    markSlot:SetSize(27, 27)
    markSlot.Disc = markSlot:CreateTexture(nil, "BACKGROUND")
    markSlot.Disc:SetTexture(ns.DISC)
    markSlot.Disc:SetAllPoints()
    markSlot.Disc:SetVertexColor(LIT[1], LIT[2], LIT[3], 0.30)
    markSlot.Ring = markSlot:CreateTexture(nil, "ARTWORK")
    markSlot.Ring:SetTexture(ns.RING)
    markSlot.Ring:SetAllPoints()
    markSlot.Ring:SetVertexColor(LIT[1], LIT[2], LIT[3], 1)
    zones:Hide()
    return zones
end

-- The places lit while dragging: the bar but the zone's block, its two ends, the ring but its bottom arc over the
-- zone, the pockets' places.
local function showZones()
    local z, c = ensureZones(), context()
    local T, d, span, ends = c.T, c.dome, c.centre, c.ends
    local W = UIParent:GetWidth()
    local cut0, cut1 = span and span.x0 or W, span and span.x1 or W
    for i, t in ipairs(z.Bar) do
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", i == 1 and 0 or cut1, 0)
        t:SetSize(max(i == 1 and cut0 or W - cut1, 0.01), max(T, 0.01))
        t:SetShown(c.bar)
    end
    for i, t in ipairs(z.Ends) do
        t:ClearAllPoints()
        if i == 1 then
            t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
            t:SetWidth(ends.left + LOCK_ZONE)
        else
            t:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", ends.rightEdge, 0)
            t:SetWidth(ends.rightEdge - ends.right + LOCK_ZONE)
        end
        t:SetHeight(max(T, 0.01))
        t:SetShown(c.bar)
    end
    local keep = 0
    if d then
        local r = Hub.PinRadius(d)
        local size, top = 2 * r + 26, d.cy + r + 13
        local half = Hub.RING_STEP / 2
        local cut = T + half
        keep = size
        -- the bottom arc Target refuses, over the zone, stays dark
        if span and cut > d.cy - r then
            local w = sqrt(r * r - max(0, d.cy - cut) ^ 2)
            if d.cx + w + half > span.x0 and d.cx - w - half < span.x1 then
                keep = min(size, top - cut)
            end
        end
        z.Ring:ClearAllPoints()
        z.Ring:SetPoint("TOP", UIParent, "BOTTOMLEFT", d.cx, top)
        z.Ring:SetSize(size, max(keep, 0.01))
        z.Ring:SetTexCoord(0, 1, 0, max(keep, 0) / size)
    end
    z.Ring:SetShown(keep > 0)
    local size, k = Hub.PocketSize() + 4, 0
    for _, side in ipairs(POCKETS) do
        for i = 1, #c.spots[side] do
            k = k + 1
            local t = z.Pockets[k]
            if not t then
                t = z:CreateTexture(nil, "BACKGROUND")
                t:SetTexture(ns.DISC)
                t:SetVertexColor(LIT[1], LIT[2], LIT[3], 0.16)
                z.Pockets[k] = t
            end
            t:ClearAllPoints()
            t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", Hub.PocketPoint(d, c.spots[side], side, i))
            t:SetSize(size, size)
            t:Show()
        end
    end
    for i = k + 1, #z.Pockets do
        z.Pockets[i]:Hide()
    end
    markLine:Hide()
    markSlot:Hide()
    z:Show()
end

local function showMarker(t)
    for i, e in ipairs(zones.Ends) do
        e:SetAlpha(t and t.side == ENDS[i] and 1 or 0.5)
    end
    markLine:SetShown(t ~= nil and t.kind == "line")
    markSlot:SetShown(t ~= nil and t.kind == "slot")
    if t and t.kind == "line" then
        markLine:ClearAllPoints()
        markLine:SetPoint("CENTER", UIParent, "BOTTOMLEFT", t.x, t.y)
        -- on the bar, upright as tall as it; in a folder's list, across its line between two (t.w x t.h)
        markLine:SetSize(t.w or 2, t.h or max(10, ctx.T - 4))
    elseif t then
        markSlot:ClearAllPoints()
        markSlot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", t.x, t.y)
    end
end

-- ---------- Dragging ----------

local function cursorUI()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end
Drag.CursorUI = cursorUI

-- One made from the bar's menu (a folder, a macro, a note) where that menu was opened, at (ux, uy), as a drop there
-- would put it (Ikar 2026-11-20: "when adding a note, a macro or a folder, it shoudl appear where the user put it.,
-- not on the right"); at the bar's right end where nothing can go (the zone's block, no place given). Not drawn.
function Drag.PlaceAt(name, ux, uy)
    local t = ux and not dragging and Drag.Target(ux, uy)
    if t and t.side == "free" then
        Hub.Save(name, { side = "free", pos = t.pos })
    elseif t and t.side == "folder" then
        Hub.InsertIntoFolder(name, t.folder, t.index)
    elseif t then
        Hub.Insert(name, t.side, t.index, t.angle)
    else
        Hub.Insert(name, "right", 1)
    end
end

-- What's dragged under the pointer: what the pointer took, and a Blizzard widget or map button under its handle.
local function follow(ux, uy)
    if not dragFrame then
        return
    end
    local k = UIParent:GetEffectiveScale() / dragFrame:GetEffectiveScale()
    dragFrame:ClearAllPoints()
    dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux * k, uy * k)
    local native = ns.Natives.Frame(dragging)
    if native and native ~= dragFrame then
        local kn = UIParent:GetEffectiveScale() / native:GetEffectiveScale()
        native:ClearAllPoints()
        native:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux * kn, uy * kn)
    elseif ns.Collect.Frame(dragging) then
        ns.Collect.Follow(dragging, ux, uy)
    end
end

local function tick()
    if InCombatLockdown() then
        Drag.Cancel()
        return
    end
    local ux, uy = cursorUI()
    follow(ux, uy)
    showMarker(Drag.Target(ux, uy))
end

-- What a drag sets up as it starts, with its first frame: the open folders stay open meanwhile, a folder dragged shut;
-- a macro dragged runs nothing, the click ending the drag being no click.
local function setUp(name)
    ns.Folders.HoldOpen()
    if ns.Folders.IsFolder(name) then
        ns.Folders.HidePanel(name)
    elseif ns.Macros.IsMacro(name) then
        ns.Macros.Disarm(name, true)
    end
    GameTooltip:Hide()
    Buttons.Highlights(false)
    if dragFrame then
        dragFrame:SetFrameStrata("TOOLTIP")
    end
    showZones()
    tick()
end

-- Starts dragging `name`, `frame` (what the pointer took, our button by default) following the pointer; false while
-- locked, for the zone, while another is dragged, or in a fight (with the game's own error line).
-- An error while something is dragged puts it back where it stood (Cancel), kept once: the first frame's here, each
-- later one's through ns.EveryFrame, the rule of what runs every frame (the review of 2026-11-16, which this drag
-- had escaped: an error there came back every frame, unguarded, and left the hub dragging until a reload).
function Drag.Begin(name, frame)
    if Hub.IsLocked() or dragging or Hub.IsFixed(name) or not Hub.Entry(name) or ns.CombatRefused() then
        return false
    end
    dragging = name
    dragFrame = frame or Buttons.Get(name) or Buttons.Handle(name)
    watcher = watcher or CreateFrame("Frame", nil, nil)
    if not ns.SafeCall(setUp, name) then
        Drag.Cancel()
        return false
    end
    -- a fight that started in that first frame has put it back already
    if dragging == name then
        ns.EveryFrame(watcher, tick, Drag.Cancel)
    end
    return dragging == name
end

-- A macro dragged runs again, once the click that ended its drag has passed.
local function rearm(name)
    if ns.Macros.IsMacro(name) then
        C_Timer.After(0, function()
            ns.SafeCall(ns.Macros.Disarm, name, false)
        end)
    end
end

-- Put back where it stood: a fight starting, the bar holding still then.
function Drag.Cancel()
    if not dragging then
        return
    end
    local name = dragging
    dragging, dragFrame = nil, nil
    if watcher then
        ns.EveryFrame(watcher, nil)
    end
    if zones then
        zones:Hide()
    end
    Buttons.Highlights(true)
    rearm(name)
    Hub.Redraw()
end

-- Drops what's dragged where the pointer is; off the places it goes back, as it does when where it lands can't be read.
-- Out of a locked folder (UI/Hub/Seeds.lua), what lands is a copy, the dragged one going back (Ikar 2026-11-23: "if
-- they drag and drop, it create a copy"); a drop back into one lands nowhere (Folders.CanHold).
function Drag.Finish()
    if not dragging then
        return
    end
    local name = dragging
    local ok, t = ns.SafeCall(Drag.Target, cursorUI())
    if not ok then
        Drag.Cancel()
        return
    end
    local side = t and t.side
    local index, angle, pos, folder = t and t.index, t and t.angle, t and t.pos, t and t.folder
    dragging, dragFrame = nil, nil
    ns.EveryFrame(watcher, nil)
    zones:Hide()
    Buttons.Highlights(true)
    rearm(name)
    if not side then
        Hub.Redraw()
        return
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    -- one action, undone from the bar's menu (UI/Hub/History.lua)
    local copy = ns.Seeds.InLockedFolder(name)
    local put = ns.History.Do(copy and "copy" or "move", name, function()
        local put = copy and ns.Seeds.Copy(name) or name
        if side == "free" then
            Hub.Save(put, { side = "free", pos = pos })
        elseif side == "folder" then
            Hub.InsertIntoFolder(put, folder, index)
        else
            Hub.Insert(put, side, index, angle)
        end
        return put
    end)
    -- the copy lit where it landed, the one dragged back in its folder
    if copy and put then
        ns.InfoBar.Flash(put)
    end
end
