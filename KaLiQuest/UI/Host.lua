-- Blizzard's tracker as the host. It stays, for Edit Mode, the timer panel and other addons, with its own title
-- and sections parked under a hidden frame. Blizzard's code keeps running on them unseen. Nothing is written into
-- Blizzard's tables but secure hooks, and nothing of Blizzard's is shown or updated from here.
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
    log("parked %d frames, host width %s", #parked, tostring(Host.width))
end

-- The rows' width option plus the scrollbar's room, zoomed as the rows are, so Edit Mode's box fits them. Only while
-- parked: unparked, the host is Blizzard's.
function Host.SetWidth(width, zoom)
    local w = (width + Host.SCROLLBAR_ROOM) * (zoom or 1)
    if not parked or Host.width == w then
        return
    end
    Host.width = w
    pcall(ObjectiveTrackerFrame.SetWidth, ObjectiveTrackerFrame, w)
end

-- Blizzard's "Temps" panel of timed quests sits 10 under the host's top and leaves its own height plus 18 above the
-- sections. Here it's scaled with the text as the popups are, up to the rows' width, then zoomed with them, and
-- centred on the rows, which the scrollbar's room puts left of the host's centre.
local TIMER_WIDTH, TIMER_TOP, TIMER_SPACING = 158, 10, 18
local timerScale, timerZoom

-- In the rows' own units, which the zoom scales.
local function timerRoom(zoom)
    local timer = QuestTimerFrame
    if timer and timer.GetTopPadding then
        local ok, room = pcall(timer.GetTopPadding, timer)
        if ok and type(room) == "number" and room > 0 then
            return (room - TIMER_SPACING) * (timer:GetScale() or 1) / zoom + TIMER_SPACING
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
        if scale ~= timerScale or zoom ~= timerZoom then
            timerScale, timerZoom = scale, zoom
            timer:SetScale(scale)
            timer:ClearAllPoints()
            local x, y = -Host.SCROLLBAR_ROOM / 2 * zoom / scale, -TIMER_TOP * zoom / scale
            timer:SetPoint("TOP", ObjectiveTrackerFrame, "TOP", x, y)
        end
    end
    return timerRoom(zoom)
end

local function resetTimer()
    local timer = QuestTimerFrame
    if timer and timerScale then
        timerScale, timerZoom = nil, nil
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

-- The root hangs from the host while it's shown, so Forever Quest Tint finds the titles there and fading applied to
-- the host applies to the rows. Blizzard hides the host when it tracks nothing, so the root then moves to UIParent
-- and stays on screen.
function Host.Place(root)
    local host = ObjectiveTrackerFrame
    root:SetParent(host:IsShown() and host or UIParent)
    root:SetFrameStrata("LOW")
    root:ClearAllPoints()
    if shadow then
        shadow:Hide()
    end
    local moved = host.IsInDefaultPosition and not host:IsInDefaultPosition()
    if host:GetTop() then
        root:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    elseif moved and host:GetPoint(1) then
        root:SetPoint("TOPLEFT", shadowOf(host), "TOPLEFT", 0, 0)
    elseif RightManagedFrameContainer then
        -- A host never shown since login has no position yet. At its default place it would top this container.
        root:SetPoint("TOPRIGHT", RightManagedFrameContainer, "TOPRIGHT", -Host.SCROLLBAR_ROOM, 0)
    else
        root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -Host.SCROLLBAR_ROOM - 5, -280)
    end
end

local hooked = false
function Host.Follow(root)
    if hooked or not ObjectiveTrackerFrame then
        return
    end
    hooked = true
    local function place()
        if ns.Tracker.IsActive() then
            ns.SafeCall(Host.Place, root)
        end
    end
    ObjectiveTrackerFrame:HookScript("OnShow", place)
    ObjectiveTrackerFrame:HookScript("OnHide", place)
    -- Edit Mode's height and the screen's size reach the rows. Away from the default position, a height set in
    -- Edit Mode wins over the addon's own until that's changed again: the last change wins.
    ObjectiveTrackerFrame:HookScript("OnSizeChanged", function()
        if not ns.Tracker.IsActive() then
            return
        end
        local host = ObjectiveTrackerFrame
        local o = ns.db.options
        local moved = host.IsInDefaultPosition and not host:IsInDefaultPosition()
        local h = host:GetHeight()
        if moved and type(h) == "number" then
            if o.editModeHeight and math.abs(o.editModeHeight - h) > 0.5 then
                o.height = nil
            end
            o.editModeHeight = h
        end
        ns.RequestRefresh()
    end)
end

-- The height the rows may use, below the timer panel when it shows.
function Host.Height()
    local host = ObjectiveTrackerFrame
    local h = host and host:GetTop() and host:GetHeight() or 0
    return h > 0 and h or 600
end

-- Edit Mode's background opacity, which Blizzard applies to the background now parked.
function Host.BackgroundAlpha()
    local manager = ObjectiveTrackerManager
    return manager and type(manager.backgroundAlpha) == "number" and manager.backgroundAlpha or 0
end
