-- KaLi HUD's own items, from Ikar's Titan bar: the zone and, either side of it, the coordinates and the clock below
-- the dome; bags, gold, repair and experience on the left; performance and volume on the right; speed hidden. Each is a
-- LibDataBroker data object (UI/Hub/Hub.lua publishes them), so another display shows them too; a value that changes
-- redraws its own button alone (Hub.Set).
local _, ns = ...

local Items = {}
ns.Items = Items

local L, Format, Hub = ns.L, ns.Format, ns.Hub
local Set = Hub.Set
local floor = math.floor

local GREY, WHITE, GOLD = { 0.5, 0.5, 0.5 }, { 1, 1, 1 }, { 1, 0.82, 0 }

local function options()
    return ns.db.options
end

local function hint(tooltip, text)
    tooltip:AddLine(text, GREY[1], GREY[2], GREY[3], true)
end

local function line(tooltip, left, right)
    tooltip:AddDoubleLine(left, right, GOLD[1], GOLD[2], GOLD[3], WHITE[1], WHITE[2], WHITE[3])
end

local function toggle(key)
    return function()
        local o = options()
        o[key] = not o[key]
        Items.Update()
    end
end

local function checked(key)
    return function()
        return options()[key]
    end
end

-- ---------- Location ----------

local LOCATION = "KaLiHUD_Location"

-- The map the player's own key opens (Ikar 2026-11-21: "qhen opening the map, we open the default map, not the one
-- that open with m shortcut"): a map addon may take that key for a map of its own (Zmap: an override binding that
-- clicks a button of its own, SetOverrideBindingClick), so the key's binding is followed as pressing it would: that
-- button's click, an addon's and not a secure one; else the game's map.
function Items.ToggleMap()
    local key = ns.Call(GetBindingKey, "TOGGLEWORLDMAP")
    local action = key and ns.Call(GetBindingAction, key, true)
    local name, button = nil, nil
    if type(action) == "string" then
        name, button = action:match("^CLICK ([^:]+):?(.*)$")
    end
    local target = name and _G[name]
    if type(target) == "table" and type(target.Click) == "function"
        and not (target.IsProtected and target:IsProtected()) then
        target:Click(button ~= "" and button or "LeftButton")
        return
    end
    ToggleWorldMap()
end

local function where()
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if pos then
        local x, y = pos:GetXY()
        if x and (x > 0 or y > 0) then
            return x, y
        end
    end
end

-- The zone's colour by its PvP state, as the game's own zone text; the same table each time, so an unchanged zone
-- changes nothing.
local ZONE_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 },
    friendly = { 0.22, 0.92, 0.22 },
    hostile = { 1.00, 0.22, 0.22 },
    contested = { 1.00, 0.72, 0.12 },
}
ZONE_COLORS.arena, ZONE_COLORS.combat = ZONE_COLORS.hostile, ZONE_COLORS.hostile
local NEUTRAL = { 1.00, 0.82, 0.00 }

local function zoneColor()
    local pvp = C_PvP and ns.Call(C_PvP.GetZonePVPInfo)
    return ZONE_COLORS[pvp] or NEUTRAL
end

local function updateLocation()
    Set(LOCATION, "textColor", zoneColor())
    Set(LOCATION, "text", GetMinimapZoneText() or GetZoneText() or "")
end

-- The zone stays under the map, between the elements set there; its tooltip and click are the map's.
Hub.Add(LOCATION, {
    type = "data source", label = L.ITEM_LOCATION, text = "", fixed = true,
    OnTooltipShow = function(tooltip)
        tooltip:SetText(GetZoneText() or "", GOLD[1], GOLD[2], GOLD[3])
        local sub = GetSubZoneText()
        if sub and sub ~= "" then
            tooltip:AddLine(sub, WHITE[1], WHITE[2], WHITE[3])
        end
        local x, y = where()
        if x then
            line(tooltip, L.COORDS, Format.Coords(x, y))
        end
        hint(tooltip, L.HINT_MAP)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" and not ns.CombatRefused() then
            Items.ToggleMap()
        end
    end,
}, "centre", 2)

-- ---------- Coordinates ----------

local COORDS = "KaLiHUD_Coords"

local function updateCoords()
    local x, y = where()
    Set(COORDS, "text", x and Format.Coords(x, y) or "")
end

Hub.Add(COORDS, {
    type = "data source", label = L.COORDS, text = "", atlas = "Waypoint-MapPin-ChatIcon", category = "world",
    OnTooltipShow = function(tooltip)
        tooltip:SetText(L.COORDS, GOLD[1], GOLD[2], GOLD[3])
        local x, y = where()
        line(tooltip, GetMinimapZoneText() or GetZoneText() or "", x and Format.Coords(x, y) or L.NO_COORDS)
        hint(tooltip, L.HINT_COORDS)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" and not ns.CombatRefused() then
            Items.ToggleMap()
        end
    end,
}, "centre", 1)

-- ---------- Clock ----------

local CLOCK = "KaLiHUD_Clock"

-- The game's own two settings, those of its clock's window (which a click on ours opens): twenty-four hours, and the
-- local time in place of the realm's. Ours, « Format 24 heures » and « Afficher l'heure du royaume », stood beside
-- them and could say otherwise (the review of 2026-11-17, its second round's 11; Ikar: "Agreed"): gone, two options
-- fewer. Read each second with the time, so a change in that window shows at once.
local function military()
    return GetCVar("timeMgrUseMilitaryTime") == "1"
end

local function realmTime()
    return GetCVar("timeMgrUseLocalTime") ~= "1"
end

local function clockText(server)
    local h, m
    if server then
        h, m = GetGameTime()
    else
        local t = date("*t")
        h, m = t.hour, t.min
    end
    if military() then
        return string.format("%02d:%02d", h, m)
    end
    local suffix = h < 12 and ns.G("TIMEMANAGER_AM", "AM") or ns.G("TIMEMANAGER_PM", "PM")
    h = h % 12
    return string.format("%d:%02d %s", h == 0 and 12 or h, m, suffix)
end

local function updateClock()
    Set(CLOCK, "text", clockText(realmTime()))
end

Hub.Add(CLOCK, {
    type = "data source", label = L.ITEM_CLOCK, text = "", atlas = "auctionhouse-icon-clock", category = "world",
    OnTooltipShow = function(tooltip)
        tooltip:SetText(L.ITEM_CLOCK, GOLD[1], GOLD[2], GOLD[3])
        line(tooltip, L.LOCAL_TIME, clockText(false))
        line(tooltip, L.SERVER_TIME, clockText(true))
        line(tooltip, L.DATE, date("%d/%m/%Y"))
        hint(tooltip, L.HINT_CLOCK)
    end,
    OnClick = function(_, button)
        if button ~= "LeftButton" then
            return
        end
        if IsShiftKeyDown() then
            if not ns.CombatRefused() and _G.ToggleCalendar then
                ns.Call(_G.ToggleCalendar)
            end
            return
        end
        if not _G.TimeManager_Toggle then
            C_AddOns.LoadAddOn("Blizzard_TimeManager")
        end
        ns.Call(_G.TimeManager_Toggle)
    end,
    menu = {
        { text = L.OPEN_CALENDAR, func = function()
            if not ns.CombatRefused() and _G.ToggleCalendar then
                ns.Call(_G.ToggleCalendar)
            end
        end },
    },
}, "centre", 3)

-- ---------- Bags ----------

local BAGS = "KaLiHUD_Bags"

-- Free and total slots of the bags that hold anything: profession bags apart, as the game's own count.
function Items.BagSlots()
    local last = Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots or 4
    local free, total = 0, 0
    for bag = 0, last do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        local empty, family = C_Container.GetContainerNumFreeSlots(bag)
        if slots > 0 and (family == nil or family == 0) then
            total = total + slots
            free = free + (empty or 0)
        end
    end
    return free, total
end

local function updateBags()
    local free, total = Items.BagSlots()
    Set(BAGS, "text", options().bagsFree and tostring(free) or string.format("%d/%d", total - free, total))
end

Hub.Add(BAGS, {
    type = "data source", label = L.ITEM_BAGS, text = "", atlas = "bag-main", category = "character",
    OnTooltipShow = function(tooltip)
        local free, total = Items.BagSlots()
        tooltip:SetText(L.ITEM_BAGS, GOLD[1], GOLD[2], GOLD[3])
        line(tooltip, L.BAGS_USED, string.format("%d/%d", total - free, total))
        line(tooltip, L.BAGS_FREE, tostring(free))
        hint(tooltip, L.HINT_BAGS)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" then
            ToggleAllBags()
        end
    end,
    options = { "bagsFree" },
    menu = { { text = L.BAGS_SHOW_FREE, checked = checked("bagsFree"), func = toggle("bagsFree") } },
}, "left", 1)

-- ---------- Gold ----------

local GOLD_ITEM = "KaLiHUD_Gold"
local session = {}

local function moneyText(m)
    if not options().copper then
        m = m - m % 100
    end
    return GetMoneyString(m, true)
end

local function updateGold()
    local m = GetMoney()
    local _, class = UnitClass("player")
    ns.db.gold[ns.CharKey()] = { money = m, class = class, name = UnitName("player"), realm = GetRealmName(), t = time() }
    session.start = session.start or m
    session.since = session.since or GetTime()
    Set(GOLD_ITEM, "text", moneyText(m))
end

Hub.Add(GOLD_ITEM, {
    type = "data source", label = L.ITEM_GOLD, text = "", atlas = "auctionhouse-icon-coin-gold", category = "character",
    OnTooltipShow = function(tooltip)
        tooltip:SetText(L.ITEM_GOLD, GOLD[1], GOLD[2], GOLD[3])
        local chars, total = {}, 0
        for _, c in pairs(ns.db.gold) do
            chars[#chars + 1] = c
            total = total + c.money
        end
        table.sort(chars, function(a, b)
            return a.money > b.money
        end)
        for _, c in ipairs(chars) do
            local colour = RAID_CLASS_COLORS and c.class and RAID_CLASS_COLORS[c.class]
            local name = tostring(c.name or "?")
            if c.realm ~= GetRealmName() then
                name = name .. " - " .. tostring(c.realm)
            end
            line(tooltip, colour and colour:WrapTextInColorCode(name) or name, moneyText(c.money))
        end
        line(tooltip, L.GOLD_TOTAL, moneyText(total))
        local change = GetMoney() - (session.start or GetMoney())
        local hours = (GetTime() - (session.since or GetTime())) / 3600
        line(tooltip, L.GOLD_SESSION, (change < 0 and "-" or "") .. moneyText(math.abs(change)))
        if hours > 0.05 then
            local rate = change / hours
            line(tooltip, L.GOLD_PER_HOUR, (rate < 0 and "-" or "") .. moneyText(floor(math.abs(rate))))
        end
        Items.MeasureLine(tooltip)
        hint(tooltip, L.HINT_GOLD)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" and not ns.CombatRefused() then
            ToggleCharacter("TokenFrame")
        end
    end,
    options = { "copper" },
    menu = { { text = L.GOLD_COPPER, checked = checked("copper"), func = toggle("copper") } },
}, "left", 2)

-- ---------- Repair ----------

local REPAIR = "KaLiHUD_Repair"
-- The slots that wear: head, shoulders, chest, waist, legs, feet, wrists, hands, both hands, ranged.
local WORN = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

-- The most worn item's share left and its slot; 1 and nil when nothing wears.
function Items.Durability()
    local low, lowSlot = 1, nil
    for _, slot in ipairs(WORN) do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 and cur / max < low then
            low, lowSlot = cur / max, slot
        end
    end
    return low, lowSlot
end

local function repairCost()
    local cost = 0
    for _, slot in ipairs(WORN) do
        local data = C_TooltipInfo and ns.Call(C_TooltipInfo.GetInventoryItem, "player", slot)
        if type(data) == "table" and type(data.repairCost) == "number" then
            cost = cost + data.repairCost
        end
    end
    return cost
end

local function updateRepair()
    local low = Items.Durability()
    local colour = low >= 0.5 and "ffffffff" or low >= 0.2 and "ffffd200" or "ffff4040"
    Set(REPAIR, "text", "|c" .. colour .. Format.Percent(low) .. "|r")
end

Hub.Add(REPAIR, {
    type = "data source", label = L.ITEM_REPAIR, text = "", atlas = "Crosshair_Repair_32", category = "character",
    OnTooltipShow = function(tooltip)
        local low, slot = Items.Durability()
        tooltip:SetText(L.ITEM_REPAIR, GOLD[1], GOLD[2], GOLD[3])
        if slot then
            line(tooltip, GetInventoryItemLink("player", slot) or L.REPAIR_WORST, Format.Percent(low))
        end
        local cost = repairCost()
        line(tooltip, L.REPAIR_COST, cost > 0 and GetMoneyString(cost, true) or L.REPAIR_NONE)
        hint(tooltip, L.HINT_CHARACTER)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" and not ns.CombatRefused() then
            ToggleCharacter("PaperDollFrame")
        end
    end,
}, "left", 3)

-- ---------- Experience ----------

local XP = "KaLiHUD_XP"
local xp = { gained = 0 }

local function atMaxLevel()
    local max = ns.Call(GetMaxLevelForPlayerExpansion)
    return type(max) == "number" and UnitLevel("player") >= max
end

local function updateXP()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if xp.last and cur and xp.lastMax then
        xp.gained = xp.gained + (cur >= xp.last and cur - xp.last or xp.lastMax - xp.last + cur)
    end
    xp.last, xp.lastMax = cur, max
    xp.since = xp.since or GetTime()
    if atMaxLevel() or not (max and max > 0) then
        Set(XP, "text", L.XP_MAX)
    else
        Set(XP, "text", string.format(L.XP_TEXT, Format.Percent(cur / max)) .. ((GetXPExhaustion() or 0) > 0 and " +" or ""))
    end
end

-- Experience per hour this session, and the time to the next level at that pace.
function Items.XPRate()
    local hours = (GetTime() - (xp.since or GetTime())) / 3600
    local rate = hours > 0 and xp.gained / hours or 0
    local left = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
    return rate, rate > 0 and left / rate * 3600 or nil
end

Hub.Add(XP, {
    type = "data source", label = L.ITEM_XP, text = "", category = "character",
    OnTooltipShow = function(tooltip)
        tooltip:SetText(string.format(L.XP_LEVEL, UnitLevel("player")), GOLD[1], GOLD[2], GOLD[3])
        if not atMaxLevel() then
            local cur, max = UnitXP("player"), UnitXPMax("player")
            line(tooltip, L.ITEM_XP, Format.Number(cur) .. " / " .. Format.Number(max))
            local rested = GetXPExhaustion() or 0
            if rested > 0 then
                line(tooltip, L.XP_RESTED, Format.Number(rested))
            end
            local rate, toLevel = Items.XPRate()
            line(tooltip, L.XP_SESSION, Format.Number(xp.gained))
            line(tooltip, L.XP_PER_HOUR, Format.Short(rate))
            line(tooltip, L.XP_TO_LEVEL, Format.Duration(toLevel))
            Items.MeasureLine(tooltip)
        end
        hint(tooltip, L.HINT_XP)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" and not ns.CombatRefused() then
            ToggleCharacter("ReputationFrame")
        end
    end,
}, "left", 4)

-- ---------- A new measure ----------
-- What the session counts starts again from now (the review of 2026-11-17, second round; Ikar: "Why not"): the gold
-- won and its rate, the experience and its rate here; the deaths and the time in UI/Hub/Infos/Session.lua, whose
-- readout's menu asks for it. A dungeon's run, an hour of gathering: started at its door, read at its end. Nothing
-- saved: a login starts a session, and its measure with it.
local measured

-- When the last measure started (GetTime); nil for none since login.
function Items.MeasureSince()
    return measured
end

function Items.NewMeasure()
    measured = GetTime()
    session.start, session.since = GetMoney(), measured
    xp.gained, xp.since = 0, measured
    Items.Update()
end

-- Under a tooltip's figures of the session, while a measure runs: since when they count.
function Items.MeasureLine(tooltip)
    if measured then
        hint(tooltip, string.format(L.MEASURE_SINCE, Format.Duration(GetTime() - measured)))
    end
end

-- ---------- Performance ----------

local PERF = "KaLiHUD_Performance"

local function latency()
    local _, _, home, world = GetNetStats()
    return home or 0, world or 0
end

local function updatePerf()
    local _, world = latency()
    Set(PERF, "text", string.format(L.PERF_TEXT, floor(GetFramerate() + 0.5), world))
end

Hub.Add(PERF, {
    type = "data source", label = L.ITEM_PERF, text = "", category = "system",
    OnTooltipShow = function(tooltip)
        local home, world = latency()
        tooltip:SetText(L.ITEM_PERF, GOLD[1], GOLD[2], GOLD[3])
        line(tooltip, L.PERF_FPS, tostring(floor(GetFramerate() + 0.5)))
        line(tooltip, L.PERF_HOME, home .. " ms")
        line(tooltip, L.PERF_WORLD, world .. " ms")
        UpdateAddOnMemoryUsage()
        local list, total = {}, 0
        for i = 1, C_AddOns.GetNumAddOns() do
            local kb = GetAddOnMemoryUsage(i) or 0
            if kb > 0 then
                list[#list + 1] = { name = C_AddOns.GetAddOnInfo(i), kb = kb }
                total = total + kb
            end
        end
        table.sort(list, function(a, b)
            return a.kb > b.kb
        end)
        line(tooltip, L.PERF_MEMORY, string.format(L.MEGABYTES, Format.Decimal(total / 1024, 1)))
        for i = 1, math.min(8, #list) do
            tooltip:AddDoubleLine("  " .. tostring(list[i].name), string.format(L.MEGABYTES, Format.Decimal(list[i].kb / 1024, 1)),
                0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        end
        hint(tooltip, L.HINT_PERF)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" then
            collectgarbage("collect")
            UpdateAddOnMemoryUsage()
        end
    end,
    -- its click opens nothing: its tooltip stays, drawn again with the memory freed (UI/Hub/Buttons.lua's onClick)
    keepsTip = true,
}, "right", 1)

-- ---------- Speed ----------

local SPEED = "KaLiHUD_Speed"
local BASE_SPEED = 7

-- The game hides speeds from addons while unit stats are restricted, in a fight (secret values, which ns.Plain gives
-- as nil): the last one shown stays, and the tooltip keeps to its title.
local function updateSpeed()
    local cur = ns.Plain(GetUnitSpeed("player"))
    if not cur then
        return
    end
    Set(SPEED, "text", Format.Percent(cur / BASE_SPEED))
end

Hub.Add(SPEED, {
    type = "data source", label = L.ITEM_SPEED, text = "", atlas = "poi-traveldirections-arrow", category = "character",
    OnTooltipShow = function(tooltip)
        local _, run, flight, swim = ns.Plain(GetUnitSpeed("player"))
        tooltip:SetText(L.ITEM_SPEED, GOLD[1], GOLD[2], GOLD[3])
        if not run then
            return
        end
        line(tooltip, L.SPEED_RUN, Format.Percent((run or 0) / BASE_SPEED))
        line(tooltip, L.SPEED_SWIM, Format.Percent((swim or 0) / BASE_SPEED))
        if (flight or 0) > 0 then
            line(tooltip, L.SPEED_FLIGHT, Format.Percent(flight / BASE_SPEED))
        end
    end,
}, "hidden", 2)

-- ---------- Volume ----------

local VOLUME = "KaLiHUD_Volume"
-- Each channel's CVar, with the game's own name for it.
Items.CHANNELS = {
    { cvar = "Sound_MasterVolume", name = "MASTER_VOLUME", fallback = "Master" },
    { cvar = "Sound_MusicVolume", name = "MUSIC_VOLUME", fallback = "Music" },
    { cvar = "Sound_SFXVolume", name = "FX_VOLUME", fallback = "Effects" },
    { cvar = "Sound_AmbienceVolume", name = "AMBIENCE_VOLUME", fallback = "Ambience" },
    { cvar = "Sound_DialogVolume", name = "DIALOG_VOLUME", fallback = "Dialog" },
}

local function volume(cvar)
    return tonumber(GetCVar(cvar)) or 0
end

local function muted()
    return GetCVar("Sound_EnableAllSound") == "0"
end

local function setVolume(cvar, v)
    SetCVar(cvar, string.format("%.2f", math.max(0, math.min(1, v))))
    Items.Update()
end

local function updateVolume()
    Set(VOLUME, "text", muted() and L.MUTED or Format.Percent(volume("Sound_MasterVolume")))
end

local function volumeMenu()
    local entries = {}
    for _, c in ipairs(Items.CHANNELS) do
        local steps = {}
        for step = 10, 0, -1 do
            steps[#steps + 1] = { text = Format.Percent(step / 10), radio = true, checked = function()
                return floor(volume(c.cvar) * 10 + 0.5) == step
            end, func = function()
                setVolume(c.cvar, step / 10)
            end }
        end
        entries[#entries + 1] = { text = ns.G(c.name, c.fallback), items = steps }
    end
    entries[#entries + 1] = { divider = true }
    entries[#entries + 1] = { text = L.MUTE, checked = muted, func = function()
        SetCVar("Sound_EnableAllSound", muted() and "1" or "0")
        Items.Update()
    end }
    return entries
end

Hub.Add(VOLUME, {
    type = "data source", label = L.ITEM_VOLUME, text = "", atlas = "chatframe-button-icon-speaker-on", category = "system",
    OnTooltipShow = function(tooltip)
        tooltip:SetText(L.ITEM_VOLUME, GOLD[1], GOLD[2], GOLD[3])
        for _, c in ipairs(Items.CHANNELS) do
            line(tooltip, ns.G(c.name, c.fallback), Format.Percent(volume(c.cvar)))
        end
        hint(tooltip, L.HINT_VOLUME)
    end,
    OnClick = function(_, button)
        if button == "LeftButton" then
            SetCVar("Sound_EnableAllSound", muted() and "1" or "0")
            Items.Update()
        end
    end,
    -- as the memory's: its click opens nothing, its tooltip stays
    keepsTip = true,
    OnMouseWheel = function(_, delta)
        setVolume("Sound_MasterVolume", volume("Sound_MasterVolume") + delta * 0.05)
    end,
    menu = volumeMenu,
}, "right", 3)

-- ---------- Updates ----------

local UPDATES = {
    location = updateLocation, coords = updateCoords, clock = updateClock, bags = updateBags, gold = updateGold,
    repair = updateRepair, xp = updateXP, perf = updatePerf, speed = updateSpeed, volume = updateVolume,
}

function Items.Update()
    for _, fn in pairs(UPDATES) do
        ns.SafeCall(fn)
    end
end

local function on(events, fn)
    for _, event in ipairs(events) do
        ns.On(event, function()
            ns.SafeCall(fn)
        end)
    end
end

function Items.Start()
    on({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }, updateLocation)
    on({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }, updateBags)
    on({ "PLAYER_MONEY" }, updateGold)
    on({ "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" }, updateRepair)
    on({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION" }, updateXP)
    on({ "CVAR_UPDATE" }, updateVolume)
    Items.tickers = {
        C_Timer.NewTicker(0.5, function()
            ns.SafeCall(updateCoords)
        end),
        C_Timer.NewTicker(1, function()
            ns.SafeCall(updateClock)
            ns.SafeCall(updatePerf)
        end),
        C_Timer.NewTicker(0.25, function()
            ns.SafeCall(updateSpeed)
        end),
    }
    Items.Update()
end
