-- KaLi HUD's slash commands, /kh and /kalihud, on the shared dispatcher (Shared/Commands.lua, with the commands for
-- debugging): what the plate takes, and how far it reaches.
local _, ns = ...
local L = ns.L

local say = ns.Say
local Commands = ns.Commands

-- What the saved data's load put right or dropped: at this login, and the last time it did (Core/Main.lua keeps it);
-- nothing with nothing ever repaired.
local function repaired(d)
    local now = ns.dbInfo and ns.dbInfo.fixed or 0
    local last = type(d.lastRepair) == "table" and d.lastRepair or nil
    return (now > 0 and string.format(", %d values repaired at this login", now) or "")
        .. (last and string.format(", last repair %s (%s values, version %s)", tostring(last.when), tostring(last.fixed),
            tostring(last.version)) or "")
end

local function statusText()
    local version, build, _, interface = GetBuildInfo()
    local db = ns.db
    local d = KaLiHUDDevDB or {}
    local plate = ns.Plate and ns.Plate.last
    local lines = {
        string.format("%s %s, client %s (%s), interface %s, %s", ns.TITLE, ns.VERSION, version, build, interface, ns.LOCALE),
        "saved data: " .. (ns.disabled and ("refused, " .. ns.disabled) or not db and "not loaded"
            or ("version " .. db.version .. (ns.firstRun and ", first run" or ""))) .. repaired(d),
        string.format("screen %.0f x %.0f units, UI scale %.3f, Edit Mode %s", UIParent:GetWidth(), UIParent:GetHeight(),
            UIParent:GetEffectiveScale(), tostring(ns.Frames.IsEditing())),
        string.format("plate %s: %d frames taken, %d segments, %d slots, dome %s, reach %s, bridge %s, %d textures", tostring(db and db.options.plate),
            plate and #plate.taken or 0, plate and #plate.segs or 0, plate and #plate.slots or 0, tostring(plate and plate.dome ~= nil),
            tostring(db and db.options.reach), tostring(db and db.options.bridge), ns.Plate and ns.Plate.textures or 0),
        string.format("debug %s, events %s, chat %s, log lines %d, distinct errors %d", tostring(ns.Debug.Enabled()), tostring(d.events),
            tostring(d.chat), #(d.log or {}), ns.Count(d.errors)),
        string.format("stat cards kept %d, %d of them with a gap", ns.StatCheck and ns.StatCheck.Count() or 0,
            ns.StatCheck and select(2, ns.StatCheck.Count()) or 0),
        "combat: " .. tostring(InCombatLockdown()),
    }
    return table.concat(lines, "\n")
end
Commands.StatusText = statusText

-- /kh status: the status, what the plate takes, what the info bar holds. With the saved
-- data refused there is no info bar to tell of, and the status says why: what the command is for then (it raised an
-- error there instead, reading the items the refused data would have held).
local function fullStatus()
    return statusText() .. "\n\n" .. ns.Plate.Text() .. "\n\n" .. (ns.db and ns.Hub.Text() or ns.Report.NoData())
end
Commands.FullStatus = fullStatus

local function help()
    for _, text in ipairs(L.HELP) do
        say(text)
    end
end

-- The options page. In a fight it doesn't open and the game's own line says why; only a client without that page
-- gets the commands in its place.
local function options()
    if not ns.Options.Open() and not InCombatLockdown() then
        help()
    end
end

Commands.Add("", function()
    if ns.Frames.IsEditing() then
        ns.EditFrame.Select()
    else
        options()
    end
end)
Commands.Add("options", options)
Commands.Add("edit", function()
    ns.EditFrame.OpenEditMode()
end)
Commands.Add("help", help, true)
Commands.Add("status", function()
    ns.Debug.ShowText("status", fullStatus())
end, true)
-- Every stat card as it is now, kept for the bug report (UI/Hub/Infos/StatCheck.lua): at a camp, after a level, in a
-- form. Not in a fight, the game hiding the values.
Commands.Add("stats", function()
    local cards, gaps = ns.StatCheck.SaveAll()
    if cards then
        say(string.format(L.STAT_CHECK_SAVED, cards, gaps))
    else
        say(L.HIDDEN_IN_FIGHT)
    end
end)
-- The settings as they are, as a text to copy; a shared text to import (UI/SetWindow.lua).
Commands.Add("export", function()
    ns.SetWindow.ShareCurrent()
end)
Commands.Add("import", function()
    ns.SetWindow.AskImport()
end)
-- How far above the plate a frame may stand and still be taken: /kh reach 40.
Commands.Add("reach", function(rest)
    local o, most = ns.db.options, ns.DB.RANGES.reach[2]
    local n = tonumber(rest)
    if n and ns.Finite(n) and n >= 0 and n <= most then
        o.reach = math.floor(n + 0.5)
        ns.Plate.Request()
    elseif rest ~= "" then
        say(string.format(L.REACH_USAGE, most))
        return
    end
    say(string.format(L.REACH, o.reach))
end)
-- Widest horizontal gap closed between covered elements: /kh bridge 40.
Commands.Add("bridge", function(rest)
    local o, most = ns.db.options, ns.DB.RANGES.bridge[2]
    local n = tonumber(rest)
    if n and ns.Finite(n) and n >= 0 and n <= most then
        o.bridge = math.floor(n + 0.5)
        ns.Plate.Request()
    elseif rest ~= "" then
        say(string.format(L.BRIDGE_USAGE, most))
        return
    end
    say(string.format(L.BRIDGE, o.bridge))
end)
-- The frames read again where they stand and frozen anew, outside Edit Mode too.
Commands.Add("redraw", function()
    ns.Plate.Freeze()
    ns.ApplyAll()
    say(L.DONE)
end)

Commands.Register("KALIHUD", { "/kh", "/kalihud" }, {
    ready = function()
        return ns.db ~= nil
    end,
    unknown = function()
        say(L.UNKNOWN_COMMAND)
    end,
})
