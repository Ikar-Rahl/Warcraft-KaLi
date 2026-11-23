-- A piece of the HUD that isn't there (its file raised an error as it loaded, which the game says only with its own
-- error display on): the others start all the same, and the one missing is kept as an error that names it. The starts
-- were read from a list built in place, which a missing one ended: nothing after it started, and nothing said so (the
-- review of 2026-11-18, R3).
local F = FakeWoW
F.Fire("ADDON_LOADED", "KaLiHUD")
local start = ns.Windows.Start
ns.Windows.Start = nil
F.Fire("PLAYER_LOGIN")
F.Fire("PLAYER_ENTERING_WORLD")
F.RunTimers()
local n, said = errors()
expect(ns.StatusBars.bars ~= nil and ns.Plate.frame ~= nil and ns.InfoBar.frame ~= nil and ns.Options.page ~= nil
    and ns.InfoBar.Placed("KaLiHUD_Gold") ~= nil,
    "a piece with no start stops those after it: status bars " .. tostring(ns.StatusBars.bars ~= nil) .. ", plate "
    .. tostring(ns.Plate.frame ~= nil) .. ", info bar " .. tostring(ns.InfoBar.frame ~= nil))
expect(n == 1 and said:find("Windows.Start", 1, true) ~= nil,
    "a piece with no start isn't kept as one error that names it: " .. n .. " kept, " .. said)
ns.Windows.Start = start

-- A setting applied with a piece's part missing reaches the others, and says which is missing.
forget()
local apply = ns.Bags.Apply
ns.Bags.Apply = nil
local layouts = ns.InfoBar.refreshes
ns.ApplyAll()
F.RunTimers()
n, said = errors()
expect(ns.InfoBar.refreshes > layouts, "a setting applied with a piece's part missing doesn't reach the pieces after it")
expect(n == 1 and said:find("Bags.Apply", 1, true) ~= nil,
    "a setting applied with a piece's part missing doesn't say which: " .. n .. " kept, " .. said)
ns.Bags.Apply = apply
