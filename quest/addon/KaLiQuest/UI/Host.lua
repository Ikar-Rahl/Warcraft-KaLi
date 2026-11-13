-- Blizzard's tracker as the host. It stays, for the timer panel and other addons (Forever Quest Tint looks for the
-- titles in it, DynamicCam and LoreForever hide it by name, ForeverCore's column hangs under it), with its own title
-- and sections parked under a hidden frame. Blizzard's code keeps running on them unseen. In Edit Mode its selection
-- is see-through and lets the mouse through, so only the addon's own frame (UI/EditFrame.lua) can be picked. Nothing
-- is written into Blizzard's tables but secure hooks, and nothing of Blizzard's is shown or updated from here.
local _, ns = ...

local Host = {}
ns.Host = Host

-- The scrollbar's room right of the rows. The host is that much wider than the rows.
Host.SCROLLBAR_ROOM = 12

local hidden
local parked -- { frame, parent } pairs, while parked
local originalWidth

-- Every section of Blizzard's tracker: the ones the addon draws and the ones it watches, listed in Coverage.lua.
local function sections()
    local list = {}
    for _, group in ipairs({ ns.Coverage.DRAWN, ns.Coverage.SECTIONS }) do
        for _, s in ipairs(group) do
            list[#list + 1] = s.frame
        end
    end
    return list
end

local function log(fmt, ...)
    ns.Debug.Log("host", fmt, ...)
end

function Host.Available()
    return ObjectiveTrackerFrame ~= nil
end

function Host.IsParked()
    return parked ~= nil
end

-- Blizzard puts its sections in the host only after PLAYER_ENTERING_WORLD and VARIABLES_LOADED, later than
-- PLAYER_LOGIN, and that reparents them. A section not in it yet is parked when Blizzard adds it.
local function containerOf(section)
    local manager = ObjectiveTrackerManager
    if not (manager and manager.GetContainerForModule) then
        return ObjectiveTrackerFrame
    end
    return manager:GetContainerForModule(section)
end

local function parkFrame(f, parent)
    -- A protected frame can't be moved in combat. None was in the probe's runs, so this is only a guard.
    if InCombatLockdown() and f:IsProtected() then
        return
    end
    local ok, err = pcall(f.SetParent, f, hidden)
    if not ok then
        log("park failed: %s", tostring(err))
        return
    end
    for _, p in ipairs(parked) do
        if p.frame == f then
            return
        end
    end
    parked[#parked + 1] = { frame = f, parent = parent }
end

local addHooked = false
local function followAddedSections(host)
    if addHooked or type(host.AddModule) ~= "function" then
        return
    end
    addHooked = true
    hooksecurefunc(host, "AddModule", function(container, section)
        if parked then
            ns.SafeCall(parkFrame, section, container)
            log("parked a section Blizzard added")
        end
    end)
end

-- Moves Blizzard's title, background and sections under a hidden frame, and widens the host for the scrollbar.
function Host.Park(width, zoom)
    local host = ObjectiveTrackerFrame
    if parked or not host then
        return
    end
    hidden = hidden or CreateFrame("Frame", nil, nil)
    hidden:Hide()
    parked = {}
    followAddedSections(host)
    for _, f in ipairs({ host.Header, host.NineSlice }) do
        parkFrame(f, f:GetParent())
    end
    for _, name in ipairs(sections()) do
        local section = _G[name]
        local container = section and containerOf(section)
        if container then
            parkFrame(section, container)
        end
    end
    originalWidth = host:GetWidth()
    Host.width = nil
    Host.SetWidth(width, zoom)
    Host.HideSelection(true)
    log("parked %d frames, host width %s", #parked, tostring(Host.width))
end

-- Blizzard's selection box for its tracker in Edit Mode: see-through and deaf to the mouse while the addon draws the
-- tracker, which has its own. Two widget calls, which run no script; Blizzard only ever shows and hides the box. Its
-- dialog, open when the tracker starts, closes, as a click elsewhere would close it.
function Host.HideSelection(hide)
    local selection = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Selection
    if not selection then
        return
    end
    pcall(selection.SetAlpha, selection, hide and 0 or 1)
    pcall(selection.EnableMouse, selection, not hide)
    local dialog = EditModeSystemSettingsDialog
    if hide and dialog and dialog.attachedToSystem == ObjectiveTrackerFrame and EditModeManagerFrame
        and EditModeManagerFrame.ClearSelectedSystem and not InCombatLockdown() then
        pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
    end
end

-- How much smaller than the addon's frame a frame draws what hangs from it, or itself: 1 unless another addon scales
-- Blizzard's tracker. FlareUI's minimap matches the tracker's width to the minimap's, so in Ikar's game it draws at
-- 0.61, and the rows hanging from it did too (Ikar, 2026-11-13: in Edit Mode they filled "only a quarter" of their
-- box, and the zoom took 140 % to look right). The rows, the "Temps" panel and the host's width are scaled back by it,
-- so the zoom alone sizes the tracker.
function Host.Unscale(frame)
    local own = ns.EditFrame.Holder():GetEffectiveScale()
    local theirs = frame and frame:GetEffectiveScale()
    if type(own) ~= "number" or own <= 0 or type(theirs) ~= "number" or theirs <= 0 then
        return 1
    end
    return own / theirs
end

-- The rows' width option plus the scrollbar's room, zoomed as the rows are, so the host spans the rows on screen where
-- they follow it, and ForeverCore's column under it spans them too. Only while parked: unparked, the host is Blizzard's.
function Host.SetWidth(width, zoom)
    local w = (width + Host.SCROLLBAR_ROOM) * (zoom or 1) * Host.Unscale(ObjectiveTrackerFrame)
    if not parked or Host.width and math.abs(Host.width - w) < 0.01 then
        return
    end
    Host.width = w
    pcall(ObjectiveTrackerFrame.SetWidth, ObjectiveTrackerFrame, w)
end

-- Blizzard's "Temps" panel of timed quests sits 10 under the host's top and leaves its own height plus 18 above the
-- sections. Here it sits so on the addon's frame, scaled with the text as the popups are, up to the rows' width, then
-- zoomed with them, and centred on the rows, which the scrollbar's room puts left of the frame's centre.
local TIMER_WIDTH, TIMER_TOP, TIMER_SPACING = 158, 10, 18
local timerScale, timerZoom, timerUnscale -- its scale against the addon's frame, the zoom, and the host's undone

-- In the rows' own units, which the zoom scales.
local function timerRoom(zoom)
    local timer = QuestTimerFrame
    if timer and timer.GetTopPadding then
        local ok, room = pcall(timer.GetTopPadding, timer)
        if ok and type(room) == "number" and room > 0 then
            return (room - TIMER_SPACING) * (timerScale or timer:GetScale() or 1) / zoom + TIMER_SPACING
        end
    end
    return 0
end

-- Places the panel for the rows and returns the room it takes above them. zoom: the rows' scale.
function Host.PlaceTimer(width, textSize, zoom)
    zoom = zoom or 1
    local timer = QuestTimerFrame
    if timer and parked then
        local scale = math.min(textSize / 12, width / TIMER_WIDTH) * zoom
        local unscale = Host.Unscale(timer:GetParent())
        if scale ~= timerScale or zoom ~= timerZoom or unscale ~= timerUnscale then
            timerScale, timerZoom, timerUnscale = scale, zoom, unscale
            timer:SetScale(scale * unscale)
            timer:ClearAllPoints()
            local x, y = -Host.SCROLLBAR_ROOM / 2 * zoom / scale, -TIMER_TOP * zoom / scale
            timer:SetPoint("TOP", ns.EditFrame.Holder(), "TOP", x, y)
        end
    end
    return timerRoom(zoom)
end

local function resetTimer()
    local timer = QuestTimerFrame
    if timer and timerScale then
        timerScale, timerZoom, timerUnscale = nil, nil, nil
        timer:SetScale(1)
        timer:ClearAllPoints()
        timer:SetPoint("TOP", ObjectiveTrackerFrame, "TOP", 0, -TIMER_TOP)
    end
end

-- Gives Blizzard its frames back. Its sections lay themselves out again at its next update.
function Host.Unpark()
    if not parked then
        return
    end
    for _, p in ipairs(parked) do
        pcall(p.frame.SetParent, p.frame, p.parent)
    end
    parked = nil
    Host.width = nil
    Host.HideSelection(false)
    if originalWidth then
        pcall(ObjectiveTrackerFrame.SetWidth, ObjectiveTrackerFrame, originalWidth)
    end
    pcall(resetTimer)
    log("unparked")
end

-- A host not shown since login isn't laid out yet, but one moved in Edit Mode already has its anchors: a shown frame
-- on the same anchors stands in for it.
local shadow
local function shadowOf(host)
    shadow = shadow or CreateFrame("Frame", nil, nil)
    shadow:SetParent(UIParent)
    shadow:ClearAllPoints()
    for i = 1, host:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = host:GetPoint(i)
        if point then
            shadow:SetPoint(point, relativeTo, relativePoint, x, y)
        end
    end
    shadow:SetSize(host:GetWidth(), host:GetHeight())
    shadow:Show()
    return shadow
end

-- Where the addon's frame stands while it follows Blizzard's tracker, as the rows did before it had a frame of its
-- own: on the host's top left, on its stand-in, or where a host never shown since login would be.
function Host.Anchor(frame)
    local host = ObjectiveTrackerFrame
    if shadow then
        shadow:Hide()
    end
    local moved = host.IsInDefaultPosition and not host:IsInDefaultPosition()
    if host:GetTop() then
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    elseif moved and host:GetPoint(1) then
        frame:SetPoint("TOPLEFT", shadowOf(host), "TOPLEFT", 0, 0)
    elseif RightManagedFrameContainer then
        -- At its default place it would top this container.
        frame:SetPoint("TOPRIGHT", RightManagedFrameContainer, "TOPRIGHT", 0, 0)
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -5, -280)
    end
end

-- The root hangs from the host while it's shown, so Forever Quest Tint finds the titles there and fading applied to
-- the host applies to the rows. Blizzard hides the host when it tracks nothing, so the root then moves to UIParent
-- and stays on screen. It sits on the addon's frame, wherever that stands.
function Host.Place(root)
    local host = ObjectiveTrackerFrame
    root:SetParent(host:IsShown() and host or UIParent)
    root:SetFrameStrata("LOW")
    root:ClearAllPoints()
    root:SetPoint("TOPLEFT", ns.EditFrame.Holder(), "TOPLEFT", 0, 0)
    ns.EditFrame.Apply()
end

local hooked = false
function Host.Follow(root)
    if hooked or not ObjectiveTrackerFrame then
        return
    end
    hooked = true
    -- The rows' scale, which undoes their parent's, is worked out again at the redraw that follows.
    local function place()
        if ns.Tracker.IsActive() then
            ns.SafeCall(Host.Place, root)
            ns.RequestRefresh()
        end
    end
    ObjectiveTrackerFrame:HookScript("OnShow", place)
    ObjectiveTrackerFrame:HookScript("OnHide", place)
    -- Another addon scaling Blizzard's tracker, through Edit Mode's SetScale or the widget's own, or the interface's
    -- scale changing: the rows are scaled back at once.
    for _, method in ipairs({ "SetScale", "SetScaleBase" }) do
        if type(ObjectiveTrackerFrame[method]) == "function" then
            hooksecurefunc(ObjectiveTrackerFrame, method, function()
                if ns.Tracker.IsActive() then
                    ns.RequestRefresh()
                end
            end)
        end
    end
    ns.On("UI_SCALE_CHANGED", function()
        if ns.Tracker.IsActive() then
            ns.RequestRefresh()
        end
    end)
    -- A new size of the host reaches the rows, whose height follows it while none is set, and the addon's frame.
    ObjectiveTrackerFrame:HookScript("OnSizeChanged", function()
        if ns.Tracker.IsActive() then
            ns.RequestRefresh()
        end
    end)
end

-- The height the rows may use, below the timer panel when it shows.
function Host.Height()
    local host = ObjectiveTrackerFrame
    local h = host and host:GetTop() and host:GetHeight() or 0
    return h > 0 and h or 600
end

-- The background's opacity: the addon's own once set, Blizzard's from Edit Mode before that.
function Host.BackgroundAlpha()
    local own = ns.db and ns.db.options.bgOpacity
    if type(own) == "number" then
        return own / 100
    end
    local manager = ObjectiveTrackerManager
    return manager and type(manager.backgroundAlpha) == "number" and manager.backgroundAlpha or 0
end
