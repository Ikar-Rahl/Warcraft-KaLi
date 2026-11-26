-- A folder that stays open (UI/Hub/Folders.lua's `persist`; Ikar 2026-11-25: "can we add another option for menu, on
-- top of default, auto hide, a persist option ? when clicking outside do not close the menu ? and make it default for
-- stats"). The attributes' folder opens so. A press elsewhere leaves it open, where it shuts one opening on a click; a
-- click on its button shuts it; another folder opening shuts it still (one at a time, Ikar 2026-11-16); the pointer
-- gone, it stays (not in the game's auto-hide); in a fight, « Fermer les dossiers en combat » shuts it once the pointer
-- has been on it and left, as one opening on a click; a login keeps it open. A folder's menu offers it.
local F = FakeWoW
local L = ns.L
login()
local Folders, Buttons = ns.Folders, ns.HubButtons
local function click(id)
    F.RunScript(Buttons.Get(id), "OnClick", "LeftButton")
    F.RunTimers()
end
local function press()
    F.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    F.RunTimers()
end
-- a menu's entry by its text, however deep, with the list it stands in
local function find(entries, text)
    for _, e in ipairs(entries or {}) do
        if e.text == text then
            return e, entries
        end
        local inner, list = find(e.items, text)
        if inner then
            return inner, list
        end
    end
end
local stats, infos = Folders.ByRole("stats"), Folders.ByRole("infos")
local sp, ip = Folders.Panel(stats), Folders.Panel(infos)
expect(Folders.Setting(stats, "open") == "persist", "the attributes' folder doesn't stay open: "
    .. tostring(Folders.Setting(stats, "open")))

-- a press elsewhere: it stays open, one opening on a click (« Infos ») shuts
click(stats)
press()
local stays = sp:IsShown() and Folders.IsOpen(stats)
click(infos)
local one = ip:IsShown() and not sp:IsShown() and not Folders.IsOpen(stats)
press()
expect(stays and one and not ip:IsShown(), "a press elsewhere shuts a folder that stays open, or leaves one opening on "
    .. "a click open, or another folder opening leaves it open")

-- its button shuts it; the pointer gone, it stays
click(stats)
click(stats)
local shut = not sp:IsShown() and not Folders.IsOpen(stats)
click(stats)
F.AutoHide(1)
F.RunTimers()
expect(shut and sp:IsShown(), "a click on its button doesn't shut a folder that stays open, or it shuts once left")

-- a login keeps it open
Folders.Setup()
expect(Folders.IsOpen(stats), "a login shuts a folder that stays open")

-- in a fight, the option's rule: shut once the pointer has been on it and left
F.EnterCombat()
F.RunTimers()
-- (the pointer on it, then off it: the game's auto-hide counts from there)
sp.mouseOver = true
F.AutoHide(0.05)
sp.mouseOver = nil
F.AutoHide(0.05)
F.AutoHide(0.5)
F.RunTimers()
local fight = not sp:IsShown()
F.LeaveCombat()
F.RunTimers()
expect(fight, "in a fight, a folder that stays open doesn't shut once left, as « "
    .. L.OPT_FOLDER_COMBAT .. " » says")

-- Escape shuts the open lists as it does any menu, the ones that stay open too (Ikar 2026-11-26: "menu that stay open,
-- or stat windows, should close on esc, as any menu"); in a fight, when no addon may hide a secure list, it is the
-- game's own, the list left as it is
local function escape()
    -- (the game's Escape: each of its special windows that shows, hidden)
    for _, name in ipairs(UISpecialFrames) do
        local f = _G[name]
        if f and f:IsShown() then
            f:Hide()
        end
    end
    F.RunTimers()
end
local escaper = _G.KaLiHUDFolderEscape
click(stats)
local armed = escaper ~= nil and escaper:IsShown()
escape()
local gone = not sp:IsShown() and not Folders.IsOpen(stats) and not (escaper and escaper:IsShown())
click(infos)
escape()
local infosGone = not ip:IsShown()
click(stats)
F.EnterCombat()
F.RunTimers()
local aside = not (escaper and escaper:IsShown())
escape()
local kept = sp:IsShown()
F.LeaveCombat()
F.RunTimers()
local back = escaper ~= nil and escaper:IsShown()
escape()
expect(armed and gone and infosGone and aside and kept and back and not sp:IsShown(),
    "Escape doesn't shut an open list, one that stays open or one opening on a click, or takes it in a fight, or is "
    .. "not back after it: " .. tostring(armed) .. tostring(gone) .. tostring(infosGone) .. tostring(aside)
    .. tostring(kept) .. tostring(back))

-- a locked folder's way of opening is the player's all the same (Ikar 2026-11-25: "users shoudl be able to set opening
-- behaviour, even on locked folders"): its menu offers the four, its spec's ticked; « Au clic » chosen, it holds
-- through the code making the folder again (a login's Seeds.Sync), and a press elsewhere shuts it; its spec's way
-- chosen again, nothing of the player's is kept
local locked = Folders.Menu(stats)
local onClick, staying = find(locked, L.FOLDER_OPEN_click), find(locked, L.FOLDER_OPEN_persist)
local ticked = staying and staying.checked() and onClick and not onClick.checked()
if onClick then
    onClick.func()
end
ns.Seeds.Sync()
F.RunTimers()
click(stats)
press()
local chosen = Folders.Setting(stats, "open") == "click" and not sp:IsShown()
if staying then
    staying.func()
end
expect(ticked and chosen and Folders.Get(stats).open == nil and Folders.Setting(stats, "open") == "persist",
    "a locked folder's menu doesn't offer how it opens, its spec's ticked, or the player's choice isn't kept through "
    .. "a login, or its spec's chosen again is kept as the player's")

-- a folder's menu offers it, after « Au clic »
local mine = Folders.Create("Essai", false)
ns.Hub.Changed()
F.RunTimers()
local persist, radios = find(Folders.Menu(mine), L.FOLDER_OPEN_persist)
if persist then
    persist.func()
end
expect(persist and radios[1].text == L.FOLDER_OPEN_click and radios[2] == persist
    and Folders.Setting(mine, "open") == "persist", "a folder's menu doesn't offer to stay open after « "
    .. L.FOLDER_OPEN_click .. " »")
click(mine)
press()
expect(Folders.IsOpen(mine), "a press elsewhere shuts a folder made to stay open from its menu")
click(mine)
expect(errors() == 0, "the folders that stay open err: " .. select(2, errors()))
