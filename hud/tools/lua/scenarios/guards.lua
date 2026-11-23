-- What the game runs of the HUD's on the player's doing (a click, a hover, a menu's entry), raising an error: it
-- doesn't get out to the game, and the addon keeps it, so /kh errors and the bug report have it. Such errors went to
-- the game's handler alone (the review of 2026-11-18, R4). The runner checks besides that every handler the session
-- hands the game is guarded (hud/tools/run_tests.py's handler_problems).
local F = FakeWoW
local L = ns.L
login()
expect(not ns.Commands.StatusText():find("repair", 1, true), "a first run's status speaks of a repair")

-- `what` fails once: `press()` must not raise, and the error must be kept.
local function guarded(what, owner, key, press)
    local real = owner[key]
    owner[key] = function()
        error(what .. " fails")
    end
    local quiet = pcall(press)
    owner[key] = real
    local n, said = errors()
    expect(quiet, "an error in " .. what .. " gets out to the game")
    expect(n == 1 and said:find(what .. " fails", 1, true) ~= nil, "an error in " .. what .. " isn't kept by the addon: " .. said)
    forget()
end

guarded("the padlock's click", ns.Hub, "SetLocked", function()
    F.RunScript(ns.InfoBar.lockButton, "OnClick", "LeftButton")
end)
guarded("the padlock's hover", ns.InfoBar, "UpdateLock", function()
    F.RunScript(ns.InfoBar.lockButton, "OnEnter")
end)
guarded("a window's fold", ns.Plate, "Redraw", function()
    F.RunScript(ns.Windows.Cartouche("ChatFrame1"), "OnClick", "LeftButton")
end)
ns.db.options.chatFolded = nil
guarded("a button's hover", ns.HubMenus, "AddHints", function()
    F.RunScript(ns.HubButtons.Get("KaLiHUD_Gold"), "OnEnter")
end)
guarded("a button's drag", ns.HubDrag, "Begin", function()
    F.RunScript(ns.HubButtons.Get("KaLiHUD_Gold"), "OnDragStart")
end)
guarded("the bar's menu", ns.History, "Next", function()
    F.RunScript(ns.InfoBar.frame, "OnMouseUp", "RightButton")
end)
-- a menu's entry: the bar's own padlock box, a status bar's box
guarded("a menu's entry", ns.Hub, "SetLocked", function()
    MenuUtil.CreateContextMenu(ns.InfoBar.frame, ns.HubMenus.Bar)
    F.MenuItem(L.SLOTS_LOCKED).choose()
end)
guarded("a status bar's menu entry", ns.StatusBars, "Refresh", function()
    MenuUtil.CreateContextMenu(ns.StatusBars.bars[-1], ns.StatusBars.Menu)
    F.MenuItem(L.STATUS_TICKS).choose()
end)
ns.db.options.statusLeftTicks = nil
