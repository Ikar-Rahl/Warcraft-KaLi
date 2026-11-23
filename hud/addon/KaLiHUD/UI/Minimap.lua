-- The minimap, owned while the minimap option is on and the plate takes it (Ikar 2026-11-15: not linked, it's left as
-- Blizzard has it, nothing of ours on it): masked round, its header (zone, clock) hidden since the info bar shows both
-- right under it, its ring (Blizzard's Forever compass by default, our border round the map, one of the rings Ikar
-- picked from his own art, or none), its zoom
-- buttons always, on hover or never, an auto zoom out; at whatever size Edit Mode gives it, never scaled. It says where
-- the slot hub's elements stand round it (Dome: the plate's) and when the pointer is over it. Blizzard's widgets are
-- UI/Hub/Natives.lua's. Not owned, all is given back as it was.
local _, ns = ...

local MinimapUI = {}
ns.Minimap = MinimapUI

local Frames, Geometry = ns.Frames, ns.Geometry

local ROUND_MASK = "ui-hud-minimap-frame-generic-mask"
-- Past the map as wide as MAP_SIZE (Blizzard's, Minimap.xml): the dome's edge clears Blizzard's ring, its top ornament
-- too; the carved neck and the pins below hug it (Ikar 2026-11-14, the map 158.4 wide: 8 and 3).
local RING_TOP, RING_FOOT, MAP_SIZE = 10, 3.75, 198
-- Blizzard's ring across round a map MAP_SIZE wide (Minimap.xml, MinimapCompassTexture): no ring of Ikar's reaches
-- past it, the rim made for Blizzard's (Ikar 2026-11-16: "no matter the skin, the outer border must be preserved").
local BLIZZARD_RING = 215
-- The pointer may leave the map for this long, onto one of its buttons, before what shows on hover goes.
local HOVER_GRACE = 0.08
-- One of Ikar's rings (Data/MinimapRings.lua) has its inner edge this far inside the map's, so the map runs under it
-- and no gap shows between them (as on the bench, hud/bench/minimap.html); one wider than Blizzard's, shrunk to it,
-- further.
local ART_UNDER = 1.5

-- How the map's pieces were before we changed them (Frames.Keep).
local kept = {}
local savedShape, active = nil, false
local ringBand, ringPool, grainPool, ringArt = nil, {}, {}, nil
local zoomTimer
-- The dome in use and whether it's the plate's; dirty: something asked for the dressing to be done again; owned: the
-- option on and the plate taking the map.
local dome, onPlate, dirty, owned = nil, false, true, false
local hoverHooked, leaving = {}, false

local function roundShape()
    return "ROUND"
end

-- How far past a map mapW wide the ring reaches at the map's foot, and the dome's edge round its top, whatever the
-- ring (Ikar 2026-11-16: "no matter the skin, the outer border must be preserved. Compared to the default blizard, our
-- border rim is calculated to fit in"): round Blizzard's, RING_FOOT and RING_TOP to the map's size. Our border, one of
-- Ikar's rings or none stand inside it as Blizzard's does.
function MinimapUI.RingWidth(_, mapW)
    local k = (mapW or MAP_SIZE) / MAP_SIZE
    return RING_FOOT * k, RING_TOP * k
end

-- How wide one of Ikar's rings (`art`, Data/MinimapRings.lua) is drawn round a map of radius mapR: its inner edge
-- ART_UNDER inside the map's, or, its band reaching past Blizzard's ring so, shrunk till its band's outer edge is where
-- Blizzard's ring ends (Ikar 2026-11-16: "Blizzard's rim, rings shrunk"), its inner edge then further over the map.
function MinimapUI.ArtSize(art, mapR)
    return math.min(2 * (mapR - ART_UNDER) / art.inner, 2 * mapR * BLIZZARD_RING / MAP_SIZE / art.band)
end

-- The dome the hub's elements stand round: the plate's (onPlate, true: it has pockets); nil while the map isn't ours.
function MinimapUI.Dome()
    return dome, onPlate
end

-- Whether KaLi HUD dresses the map and places Blizzard's widgets: the option on and the plate taking it.
function MinimapUI.Owned()
    return owned
end

-- Where the map's centre stands across the screen, ours or not: the zone stands under it.
function MinimapUI.CentreX()
    if dome then
        return dome.cx
    end
    local x, _, w = Frames.Rect(_G.Minimap)
    return x and x + w / 2
end

local function sameDome(a, b)
    if a == nil or b == nil then
        return a == b
    end
    return a.cx == b.cx and a.cy == b.cy and a.mapR == b.mapR and a.ring == b.ring and a.r == b.r
end

-- Our frames round the map (`f`) are the map's own children, just over it: MinimapCluster is toplevel, so a click on
-- the map raises it over all else in its strata, and a ring of ours beside it went under the map (Ikar 2026-11-16:
-- "when clicking on a map, it draws on top of the border, this is a bug"); a child rises with it, as Blizzard's ring
-- does. In UIParent's units all the same: the map's own scale (Edit Mode's size) ignored, UIParent's taken. Blizzard's
-- cluster lays itself out round its own children only, so ours never stretch it.
local function onMap(f, map)
    if f:GetParent() ~= map then
        f:SetParent(map)
    end
    f:SetIgnoreParentScale(true)
    f:SetScale(UIParent:GetEffectiveScale())
    f:SetFrameStrata(map:GetFrameStrata())
    f:SetFrameLevel(map:GetFrameLevel() + 2)
end

-- Our border round the map (`d`, or none for nil), whole, over the plate's own edge where they meet.
local function drawRing(d)
    local map = _G.Minimap
    if not ringBand then
        if not d then
            return
        end
        ringBand = CreateFrame("Frame", nil, map)
        ringBand:SetAllPoints(UIParent)
        ringBand:EnableMouse(false)
        MinimapUI.ringBand = ringBand
    end
    onMap(ringBand, map)
    local prof = ns.Border.Profile()
    local quads = {}
    if d and prof.e > 0 then
        quads = Geometry.Band(Geometry.Circle(d.cx, d.cy, d.mapR - prof.out), prof.e)
    end
    MinimapUI.ringDrawn = ns.Border.DrawBand(ringBand, ringPool, quads, prof)
    local grain = ns.Border.Grain(prof)
    ns.Border.DrawBand(ringBand, grainPool, grain and quads or {}, grain)
    ringBand:SetShown(#quads > 0)
end

-- One of Ikar's rings (`art`, Data/MinimapRings.lua) round the map (`d`), its centre on the map's; or none, for nil.
local function drawArt(d, art)
    if not (d and art) then
        if ringArt then
            ringArt:Hide()
        end
        return
    end
    local map = _G.Minimap
    if not ringArt then
        ringArt = CreateFrame("Frame", nil, map)
        ringArt:EnableMouse(false)
        ringArt.Ring = ringArt:CreateTexture(nil, "ARTWORK")
        ringArt.Ring:SetAllPoints()
        MinimapUI.ringArt = ringArt
    end
    onMap(ringArt, map)
    ringArt.Ring:SetTexture(art.file)
    local size = MinimapUI.ArtSize(art, d.mapR)
    ringArt:ClearAllPoints()
    ringArt:SetSize(size, size)
    ringArt:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.cx, d.cy)
    ringArt:Show()
end

-- ---------- Hover ----------

local function over(r)
    return r ~= nil and r:IsShown() and r:IsMouseOver()
end

-- Whether the pointer is over the map, its zoom buttons, Blizzard's widgets or one of our elements round it.
function MinimapUI.IsHovered()
    local map = _G.Minimap
    return map:IsMouseOver() or over(map.ZoomIn) or over(map.ZoomOut) or ns.Natives.IsHovered()
        or ns.InfoBar.AnyHovered()
end

-- The zoom buttons always, on hover or never.
local function updateZoom(hovered)
    local o, map = ns.db.options, _G.Minimap
    if owned and map.ZoomIn and map.ZoomOut then
        local show = o.minimapZoom == "always" or o.minimapZoom == "hover" and hovered
        map.ZoomIn:SetShown(show)
        map.ZoomOut:SetShown(show)
        if map.ZoomHitArea then
            Frames.Keep(kept, "zoomHit", map.ZoomHitArea)
            map.ZoomHitArea:EnableMouse(show)
        end
    end
end

-- What shows on hover, shown or hidden as the pointer is or isn't over the map: the zoom buttons, Blizzard's
-- widgets and our elements round it.
function MinimapUI.UpdateHover()
    local hovered = MinimapUI.IsHovered()
    updateZoom(hovered)
    ns.Natives.UpdateVisibility(hovered)
    ns.InfoBar.UpdateHover(hovered)
end

local function leftLate()
    if leaving then
        leaving = false
        ns.SafeCall(MinimapUI.UpdateHover)
    end
end

-- Hooked on the game's frames and ours: each under the handlers' guard (ns.Guarded), made once.
local entered = ns.Guarded(function()
    leaving = false
    MinimapUI.UpdateHover()
end)

local left = ns.Guarded(function()
    leaving = true
    C_Timer.After(HOVER_GRACE, leftLate)
end)

-- The pointer entering or leaving `region` updates what shows on hover (leaving, a moment later).
function MinimapUI.HookHover(region)
    if type(region) == "table" and region.HookScript and not hoverHooked[region] then
        hoverHooked[region] = true
        region:HookScript("OnEnter", entered)
        region:HookScript("OnLeave", left)
    end
end

-- ---------- Owning the map ----------

-- Forever's own coordinates under the map (Ikar 2026-11-19: "it still show the coordinate bellow, when taking over, we
-- should hide them", "there is a option in forever to disable it"): the game's setting for them turned off as the HUD
-- takes the map, the player's value kept (DB.cvars) and put back as it gives the map back. Its own code then leaves
-- them empty, whoever else styles or fades the frame (FlareUI). Ticked again meanwhile, it stays as the player set it.
-- Put back at each logout too (a reload's as well), the value kept marked BACK, and taken again at the next login: a
-- game started without the HUD (disabled, removed) had kept them off (the review of 2026-11-23). Whether the game
-- keeps a setting changed at a logout isn't known: still off at the next login, the HUD's own 0, the kept value
-- stands.
local COORDS = "minimapShowPlayerCoords"
local BACK = ":back"

local function unmarked(was)
    return (was:gsub(BACK .. "$", ""))
end

local function takeCoords()
    local kept, now = ns.db.cvars, GetCVar(COORDS)
    local was = kept[COORDS]
    if was == nil then
        if now ~= nil then
            kept[COORDS] = now
            if now ~= "0" then
                SetCVar(COORDS, "0")
            end
        end
    elseif was:sub(-#BACK) == BACK then
        -- put back at the last logout: the player's value as it is now (the one put back, or one set since) kept and
        -- turned off again; the HUD's 0 still there, the value kept before
        if now ~= nil and now ~= "0" then
            kept[COORDS] = now
            SetCVar(COORDS, "0")
        else
            kept[COORDS] = unmarked(was)
        end
    end
end

local function giveCoords()
    local was = ns.db.cvars[COORDS]
    if was ~= nil then
        ns.db.cvars[COORDS] = nil
        SetCVar(COORDS, unmarked(was))
    end
end

-- At a logout, while the HUD holds the map and its 0 holds them off: the player's value back, marked to be taken
-- again. One ticked again by the player, or off already, is left as it is.
local function backAtLogout()
    local was = ns.db and ns.db.cvars[COORDS]
    if active and type(was) == "string" and was ~= "0" and was:sub(-#BACK) ~= BACK and GetCVar(COORDS) == "0" then
        SetCVar(COORDS, was)
        ns.db.cvars[COORDS] = was .. BACK
    end
end
-- For the tests: as at a login, a giving back, a logout.
MinimapUI.Coords = { Take = takeCoords, Give = giveCoords, Back = backAtLogout }

-- Everything as it was before the minimap option: the shape, Blizzard's ring and header, its widgets, the zoom's
-- hover area; then the cluster's own config, and its header where Edit Mode's setting has it (with the widgets it
-- places by it, mail and compartment), never forced.
local function restore()
    if not active then
        return
    end
    active = false
    _G.GetMinimapShape = savedShape
    savedShape = nil
    drawRing(nil)
    drawArt(nil)
    for _, key in ipairs({ "compass", "compassUnder", "zone", "clock", "borderTop", "zoomHit" }) do
        Frames.GiveBack(kept, key)
    end
    local map = _G.Minimap
    if map.ZoomIn and map.ZoomOut then
        map.ZoomIn:Hide()
        map.ZoomOut:Hide()
    end
    ns.Natives.Restore()
    giveCoords()
    local cluster = _G.MinimapCluster
    if type(cluster.UpdateMinimapConfig) == "function" then
        pcall(cluster.UpdateMinimapConfig, cluster)
    end
    if type(cluster.UpdateSystemSettingHeaderUnderneath) == "function" then
        pcall(cluster.UpdateSystemSettingHeaderUnderneath, cluster)
    end
end

-- The map dressed as the options say round the dome in use, Blizzard's widgets placed; or given back while not owned.
function MinimapUI.Apply()
    dirty = false
    local map = _G.Minimap
    if not map then
        return
    end
    local o = ns.db.options
    if not (owned and o.minimap) then
        restore()
        return
    end
    if not active then
        active = true
        savedShape = _G.GetMinimapShape
        _G.GetMinimapShape = roundShape
        ns.Natives.Activate()
        takeCoords()
    end
    pcall(map.SetMaskTexture, map, ROUND_MASK)
    -- the header bar (zone and clock): hidden by default, the info bar shows both right beneath the dome
    local cluster = _G.MinimapCluster
    Frames.SetHidden(kept, "zone", cluster.ZoneTextButton, not o.minimapHeader)
    Frames.SetHidden(kept, "clock", _G.TimeManagerClockButton, not o.minimapHeader)
    Frames.SetHidden(kept, "borderTop", cluster.BorderTop, not o.minimapHeader)
    -- the ring: Blizzard's Forever compass (its pointer's underlay when rotating), our border, one of Ikar's, or none
    local blizzRing = o.minimapRing == "blizzard"
    Frames.SetHidden(kept, "compass", _G.MinimapCompassTexture, not blizzRing)
    Frames.SetHidden(kept, "compassUnder", _G.MinimapCompassTextureUnderlay,
        not (blizzRing and GetCVar("rotateMinimap") == "1"))
    drawRing(o.minimapRing == "kali" and dome or nil)
    drawArt(dome, ns.MINIMAP_RINGS[o.minimapRing])
    ns.Natives.Place()
    updateZoom(MinimapUI.IsHovered())
end

-- After each plate redraw, its dome (nil when it doesn't take the map): owned or given back as it says, the dressing
-- done again when the dome moved or something asked (Request), what stands by it put back when it moved, the whole hub
-- drawn again when the map became ours or stopped being (Blizzard's widgets take a place on the bar or none), or when
-- its pockets hold more or fewer places. Live through a drag in Edit Mode too (Ikar 2026-11-16: "can't it happen
-- during drag?"): a map dragged out of the plate's reach is Blizzard's again as it goes, ours again as it comes back.
function MinimapUI.SetDome(fromPlate)
    local own = ns.db.options.minimap and fromPlate ~= nil
    local d, on = nil, false
    if own then
        d, on = fromPlate, true
    end
    local changed = own ~= owned
    owned = own
    local moved = changed or on ~= onPlate or not sameDome(d, dome)
    dome, onPlate = d, on
    if moved or dirty then
        MinimapUI.Apply()
    end
    if changed then
        ns.InfoBar.Request()
    elseif moved then
        ns.InfoBar.Reflow()
    elseif owned then
        ns.InfoBar.PocketsHold()
    end
end

local function applyIfAsked()
    if dirty then
        MinimapUI.Apply()
    end
end

-- Done again once, on the next frame (or with the next plate redraw, if sooner), however many ask.
function MinimapUI.Request()
    dirty = true
    ns.Later("minimap", applyIfAsked)
end

local function onZoomChanged()
    local o = ns.db.options
    if not owned then
        return
    end
    if zoomTimer then
        zoomTimer:Cancel()
        zoomTimer = nil
    end
    local map = _G.Minimap
    if o.minimapAutoZoom > 0 and map:GetZoom() > 0 then
        zoomTimer = C_Timer.NewTicker(o.minimapAutoZoom, function()
            zoomTimer = nil
            if ns.db.options.minimap and ns.db.options.minimapAutoZoom > 0 then
                map:SetZoom(0)
            end
        end, 1)
    end
end

-- Blizzard laying the cluster out again (its config, its header) has the dressing done again over it; Edit Mode's
-- size has the plate's dome follow.
local function hookCluster()
    local cluster, map = _G.MinimapCluster, _G.Minimap
    for _, method in ipairs({ "UpdateMinimapConfig", "SetHeaderUnderneath" }) do
        if type(cluster[method]) == "function" then
            hooksecurefunc(cluster, method, ns.Guarded(function()
                if owned then
                    MinimapUI.Request()
                end
            end))
        end
    end
    if type(cluster.SetEditModeScale) == "function" then
        hooksecurefunc(cluster, "SetEditModeScale", ns.Guarded(function()
            ns.Plate.Request()
        end))
    end
    map:HookScript("OnShow", ns.Guarded(MinimapUI.Request))
    map:HookScript("OnHide", ns.Guarded(function()
        if ringBand then
            ringBand:Hide()
        end
        if ringArt then
            ringArt:Hide()
        end
    end))
end

function MinimapUI.Start()
    local map = _G.Minimap
    hookCluster()
    -- (the coordinates under the map back as the player had them, between two sessions)
    ns.On("PLAYER_LOGOUT", backAtLogout)
    for _, region in ipairs({ map, map.ZoomIn, map.ZoomOut }) do
        MinimapUI.HookHover(region)
    end
    ns.On("MINIMAP_UPDATE_ZOOM", onZoomChanged)
    if not _G.TimeManagerClockButton and not C_AddOns.IsAddOnLoaded("Blizzard_TimeManager") then
        ns.On("ADDON_LOADED", function(_, name)
            if name == "Blizzard_TimeManager" then
                MinimapUI.HookHover(_G.TimeManagerClockButton)
                if owned then
                    MinimapUI.Request()
                end
            end
        end)
    end
end
