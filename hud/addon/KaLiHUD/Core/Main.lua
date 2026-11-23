-- Startup and logout. Saved data is first touched in this addon's own ADDON_LOADED and last in PLAYER_LOGOUT, the
-- last event before the client writes the files.
local ADDON, ns = ...

local function onAddonLoaded(_, name)
    if name ~= ADDON then
        return
    end
    ns.Off("ADDON_LOADED", onAddonLoaded)
    ns.Debug.Init()
    local data, info = ns.DB.Open(KaLiHUDDB)
    if not data then
        ns.disabled = info
        ns.Say(string.format(ns.L.DB_REFUSED, info))
        ns.Debug.Log("init", "saved data refused: %s", info)
        return
    end
    KaLiHUDDB = data
    ns.db = data
    -- a character who has settings of its own plays on them (Core/Sets.lua)
    ns.DB.Enter(data, ns.CharKey())
    -- the padlock shut at every connection and every reload, as Edit Mode never stays open across them (Ikar 2026-11-20:
    -- "make it lock on combat (no unlock after) on disconnect, on connect, on reload"): its default, shut, as the file
    -- is written
    data.options.slotsLocked = nil
    ns.dbInfo = info
    ns.firstRun = info.firstRun
    ns.Debug.Log("init", "%s %s loaded, first run %s, repaired %d", ns.TITLE, ns.VERSION, tostring(info.firstRun), info.fixed)
    -- What the load put right or dropped is said nowhere else unless debug mode is on (the review of 2026-11-18): the
    -- last time it did is kept, for /kh status and the report.
    if info.fixed > 0 then
        ns.DevDB().lastRepair = { when = date("%Y-%m-%d %H:%M"), fixed = info.fixed, version = ns.VERSION }
    end
end
ns.On("ADDON_LOADED", onAddonLoaded)

ns.On("PLAYER_LOGOUT", function()
    if ns.db then
        -- saved shut, the padlock (a disconnection too: the next connection finds it shut all the same)
        ns.db.options.slotsLocked = true
        ns.DB.BeforeSave(ns.db)
    end
end)

-- One step of a piece, "Plate.Start": run on its own, so one that fails leaves the others; one that isn't there (its
-- file raised an error as it loaded, which the game says only with its own error display on) is kept as an error that
-- names it, and the rest go on. Read from a list built in place, a piece without its step ended the list there: nothing
-- after it started, and nothing said so (the review of 2026-11-18).
local function run(step)
    local piece, method = step:match("^(%w+)%.(%w+)$")
    local fn = type(ns[piece]) == "table" and ns[piece][method]
    if type(fn) ~= "function" then
        ns.Debug.Error(step .. " isn't there: a file of " .. ns.TITLE .. " didn't load whole", "")
        return
    end
    ns.SafeCall(fn)
end

-- Applies every live setting across the HUD's pieces, at once: the plate (the map dressed round its dome), then the
-- slot hub round that dome. A setting changed: each item of the bar takes its own width again (InfoBar.Forget, its
-- place no wider than it needs now). The options page's boxes follow, while that page shows: the padlock clicked, a
-- setting put back in Edit Mode.
local APPLY = { "Border.ApplyAll", "Bags.Apply", "StatusBars.Refresh", "EditFrame.Holder", "Minimap.Request",
    "Plate.Redraw", "InfoBar.Forget", "InfoBar.Refresh", "Options.Changed" }
function ns.ApplyAll()
    if not ns.db then
        return
    end
    for _, step in ipairs(APPLY) do
        run(step)
    end
end

-- The pieces' starts, in order: the status bars before the plate, which draws their slots; Blizzard's map widgets
-- before the map, which places them; the hub after the items it publishes.
local START = { "Bags.Start", "Windows.Start", "StatusBars.Start", "Natives.Start", "Minimap.Start", "Plate.Start",
    "Items.Start", "Infos.Start", "Hub.Start", "InfoBar.Start", "Collect.Start", "EditFrame.Start", "Options.Register" }
ns.On("PLAYER_LOGIN", function()
    if not ns.db then
        return
    end
    for _, step in ipairs(START) do
        run(step)
    end
end)

-- The API check, last, once the pieces are there to be tried; with the saved data refused too, since what the game
-- answers doesn't depend on it.
ns.On("PLAYER_LOGIN", ns.SelfCheck.AtLogin)
