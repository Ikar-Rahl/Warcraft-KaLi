-- What the info bar shows beyond Ikar's Titan bar (UI/Hub/Items.lua), from his list of 2026-11-16 and its tests
-- ("I don't want to add things that belong more in a spell slot... avoid those who need serious code, tracking, data
-- storage... no one that breaks immersion, or provides gaming shortcuts that make the player a bot"): each read from one
-- of the game's own calls, or the game's own tool opened; nothing kept but what a session counts. Each item stands in
-- the folder made for it (UI/Hub/Seeds.lua, its obj.home). This file: what they share, their tooltips' lines and their
-- updates, each run at login, on its events (a unit's for the player only), coalesced to the next frame.
local _, ns = ...

local Infos = {}
ns.Infos = Infos

Infos.GOLD, Infos.WHITE, Infos.GREY = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.5, 0.5, 0.5 }
-- A value in the player's favour, against it (the character sheet's).
Infos.GOOD, Infos.BAD = "ff20ff20", "ffff2020"
local GOLD, WHITE, GREY = Infos.GOLD, Infos.WHITE, Infos.GREY

function Infos.Title(tooltip, text)
    tooltip:SetText(text or "", GOLD[1], GOLD[2], GOLD[3])
end

function Infos.Line(tooltip, left, right)
    tooltip:AddDoubleLine(left or "", right or "", GOLD[1], GOLD[2], GOLD[3], WHITE[1], WHITE[2], WHITE[3])
end

function Infos.Text(tooltip, text, wrap)
    tooltip:AddLine(text or "", WHITE[1], WHITE[2], WHITE[3], wrap ~= false)
end

function Infos.Hint(tooltip, text)
    tooltip:AddLine(text or "", GREY[1], GREY[2], GREY[3], true)
end

-- A text in a colour "aarrggbb".
function Infos.Color(text, color)
    return "|c" .. color .. tostring(text) .. "|r"
end

-- Opens one of the game's windows on a left click, not in a fight (the game's error line says why).
function Infos.Opener(open)
    return function(_, button)
        if button == "LeftButton" and not ns.CombatRefused() then
            ns.SafeCall(open)
        end
    end
end

local updates, byEvent, tickers, starts = {}, {}, {}, {}

-- The player's own unit events (UNIT_AURA, UNIT_STATS...), the game told to send the player's alone
-- (RegisterUnitEvent): registered the shared way, it sent every unit's, a raid's and the nameplates' many times a
-- second, each through the shared handlers to be dropped there (the review of 2026-11-23). Counted, traced and
-- refused as the shared ones are (Shared/Core.lua: the status, the debug log, the API check). A client without the
-- call gets every unit's, the player's alone handled.
local playerFrame, playerHandlers = nil, {}
local function firePlayer(_, event, ...)
    local counts = ns.EventCounts()
    counts[event] = (counts[event] or 0) + 1
    if ns.Debug then
        ns.Debug.TraceEvent(event, ...)
    end
    for _, fn in ipairs(playerHandlers[event] or {}) do
        ns.SafeCall(fn, event, ...)
    end
end
function Infos.OnPlayer(event, fn)
    if not playerFrame then
        playerFrame = CreateFrame("Frame", nil, nil)
        playerFrame:SetScript("OnEvent", ns.Guarded(firePlayer))
    end
    if type(playerFrame.RegisterUnitEvent) ~= "function" then
        ns.On(event, function(name, unit, ...)
            if unit == "player" then
                fn(name, unit, ...)
            end
        end)
        return
    end
    local list = playerHandlers[event]
    if not list then
        list = {}
        playerHandlers[event] = list
        local ok, registered = pcall(playerFrame.RegisterUnitEvent, playerFrame, event, "player")
        if not ok or registered == false then
            local missing = ns.MissingEvents()
            missing[#missing + 1] = event
        end
    end
    list[#list + 1] = fn
end

-- fn run at login, on each of `events` and every `every` seconds if given.
function Infos.Updates(fn, events, every)
    local key = "infos " .. (#updates + 1)
    local entry = { fn = fn, key = key }
    updates[#updates + 1] = entry
    for _, event in ipairs(events or {}) do
        byEvent[event] = byEvent[event] or {}
        table.insert(byEvent[event], entry)
    end
    if every then
        tickers[#tickers + 1] = { every = every, fn = fn }
    end
end

-- fn run once at login, before the updates.
function Infos.OnStart(fn)
    starts[#starts + 1] = fn
end

function Infos.Start()
    for _, fn in ipairs(starts) do
        ns.SafeCall(fn)
    end
    for event, list in pairs(byEvent) do
        local function run()
            for _, entry in ipairs(list) do
                ns.Later(entry.key, entry.fn)
            end
        end
        if event:find("^UNIT_") then
            Infos.OnPlayer(event, run)
        else
            ns.On(event, run)
        end
    end
    Infos.tickers = {}
    for _, t in ipairs(tickers) do
        Infos.tickers[#Infos.tickers + 1] = C_Timer.NewTicker(t.every, function()
            ns.SafeCall(t.fn)
        end)
    end
    Infos.Update()
end

function Infos.Update()
    for _, entry in ipairs(updates) do
        ns.SafeCall(entry.fn)
    end
end
