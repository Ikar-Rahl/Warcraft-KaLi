-- A frame that isn't ours raising an error as the hub places it: another addon's map button, one of Blizzard's
-- widgets. Its error took the whole bar's layout with it, as one element failing to draw did before (the review of
-- 2026-11-18, R1): the bar came up with one item of twenty-two and followed nothing after. It is kept once, the frame
-- given back as far as it lets itself be, and the hub laid out without it.
local F = FakeWoW
login()
local name = "AutoBiographerMinimapButton"
ns.Hub.Insert(name, "left", 1)
F.RunTimers()
local before = onBar()
expect(ns.InfoBar.Placed(name) ~= nil and before > 10 and errors() == 0,
    "setup: another addon's button on the bar's left, " .. before .. " items on the bar, " .. select(2, errors()))

F.rawButton.SetPoint = function()
    error("their frame refuses SetPoint")
end
ns.Hub.Changed()
F.RunTimers()
local n, said = errors()
expect(onBar() == before - 1 and ns.InfoBar.Placed("KaLiHUD_Gold") ~= nil,
    "another addon's button that can't be placed takes the bar's layout with it: " .. onBar() .. " items on the bar of "
    .. before)
expect(n == 1 and said:find("refuses SetPoint", 1, true) ~= nil,
    "the error of a button that can't be placed isn't kept once: " .. n .. " kept, " .. said)
expect(not ns.Collect.Shown(name) and ns.InfoBar.Placed(name) == nil and F.rawButton:GetParent() == Minimap,
    "a button that can't be placed isn't given back to its addon and left out of the hub")

-- The bar still follows what the player does, and the button isn't tried again.
local kept = times("refuses SetPoint")
ns.Hub.Insert("KaLiHUD_Gold", "right", 1)
F.RunTimers()
ns.Hub.Changed()
F.RunTimers()
local gold = ns.InfoBar.Placed("KaLiHUD_Gold")
expect(gold ~= nil and gold.x > UIParent:GetWidth() / 2,
    "after a button that couldn't be placed, the bar no longer follows a change")
expect(times("refuses SetPoint") == kept and kept <= 2,
    "a button that couldn't be placed is tried again at each layout: its error kept " .. kept .. " times, then "
    .. times("refuses SetPoint"))

-- One of Blizzard's widgets, the same: the calendar on the bar, its frame refusing a call the hub makes of it.
forget()
local calendar = ns.Natives.NAME.CALENDAR
ns.Hub.Insert(calendar, "left", 1)
F.RunTimers()
before = onBar()
expect(ns.InfoBar.Placed(calendar) ~= nil and errors() == 0, "setup: the calendar on the bar's left: " .. select(2, errors()))
GameTimeFrame.SetFrameStrata = function()
    error("the game's frame refuses SetFrameStrata")
end
-- each layout begun is one finished: none stopped half way, not even the one that met the error
local begun, finished = ns.InfoBar.refreshes, ns.InfoBar.Version()
ns.Hub.Changed()
F.RunTimers()
n, said = errors()
expect(ns.InfoBar.refreshes - begun == ns.InfoBar.Version() - finished,
    "one of Blizzard's widgets that can't be placed stops a layout of the bar half way: " .. (ns.InfoBar.refreshes - begun)
    .. " begun, " .. (ns.InfoBar.Version() - finished) .. " finished")
expect(onBar() == before - 1 and ns.InfoBar.Placed("KaLiHUD_Gold") ~= nil and ns.InfoBar.Placed(calendar) == nil
    and ns.Natives.Size(calendar) == 0,
    "one of Blizzard's widgets that can't be placed takes the bar's layout with it: " .. onBar() .. " items on the bar of "
    .. before)
expect(n == 1 and said:find("refuses SetFrameStrata", 1, true) ~= nil,
    "the error of a widget that can't be placed isn't kept once: " .. n .. " kept, " .. said)

-- An element whose drawing raises an error shows the question mark (the review of 2026-11-17, D5): the status and
-- the bug report now say which.
forget()
F.ldb:NewDataObject("Cassé", { type = "data source", label = "Cassé", text = setmetatable({}, { __tostring = function()
    error("an element's text fails")
end }) })
ns.Hub.Insert("Cassé", "right", 1)
F.RunTimers()
local text = ns.Hub.Text()
expect(ns.HubButtons.Failed("Cassé") and text:find("Cassé: [^\n]*FAILED TO DRAW") ~= nil
    and not text:find("KaLiHUD_Gold: [^\n]*FAILED TO DRAW"),
    "the status doesn't say which element failed to draw")
