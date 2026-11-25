-- KaLi HUD's own folders that aren't locked, « Add-ons » and « Suite » (UI/Hub/Seeds.lua): taken off the HUD from their
-- menu, never deleted for good; renamed, one is the player's, its role gone and what KaLi HUD put in it saved there,
-- where it stood (UI/Hub/Folders.lua's Rename). And the bar's menu never lists the macros, a player's own on the bar
-- among them (Ikar 2026-11-20: "The whole emote category shoudl go, keep only the folder"). The smoke's checks of
-- these ran on a locked folder, whose menu is another's, and on a bar with no macro of the player's: the breaks of
-- the review of 2026-11-17 and of 2026-11-20 had gone unseen since the folders were locked (2026-11-23).
local F = FakeWoW
local L = ns.L
login()
local Folders, Hub, Buttons = ns.Folders, ns.Hub, ns.HubButtons
local function menuOf(name)
    F.lastMenu = nil
    F.RunScript(Buttons.Get(name), "OnClick", "RightButton")
    F.RunTimers()
    return F.lastMenu
end

local addons = Folders.Default()
expect(addons and ns.Seeds.FolderSpec(addons) ~= nil and not ns.Seeds.IsLockedFolder(addons),
    "« Add-ons » isn't one of KaLi HUD's own folders, or is a locked one")
local menu = menuOf(addons)
expect(menu and F.MenuItem(L.ITEM_REMOVE, menu) ~= nil and F.MenuItem(L.FOLDER_DELETE, menu) == nil,
    "« Add-ons » is deleted for good from its menu, not taken off the HUD")

-- Renamed: the player's.
local inside = {}
for _, e in ipairs(Hub.InFolder(addons)) do
    if not Hub.Saved(e.name) then
        inside[#inside + 1] = e.name
    end
end
expect(#inside > 0, "nothing stands in « Add-ons » by default: the case isn't made")
Folders.Rename(addons, "Mes add-ons")
F.RunTimers()
local f = Folders.Get(addons)
expect(f and f.name == "Mes add-ons" and f.role == nil and ns.Seeds.FolderSpec(addons) == nil,
    "« Add-ons » renamed is still KaLi HUD's: its role " .. tostring(f and f.role))
local stayed = 0
for _, name in ipairs(inside) do
    local saved = Hub.Saved(name)
    stayed = stayed + ((saved and saved.side == "folder" and saved.folder == addons) and 1 or 0)
end
expect(stayed == #inside, "« Add-ons » renamed, what stood in it by default leaves it: " .. stayed .. " of " .. #inside
    .. " saved in it")
menu = menuOf(addons)
expect(menu and F.MenuItem(L.FOLDER_DELETE, menu) ~= nil and F.MenuItem(L.ITEM_REMOVE, menu) == nil,
    "« Add-ons » renamed isn't deleted from its menu as the player's own")

-- The bar's menu, a macro of the player's on the bar: no list of the macros.
local macro = ns.Macros.New()
F.RunTimers()
ns.MacroEditor.Close(macro)
F.RunTimers()
expect(macro and Hub.Entry(macro) and Hub.Entry(macro).side ~= "folder", "a macro made on the bar isn't on it")
F.lastMenu = nil
F.RunScript(ns.InfoBar.frame, "OnMouseUp", "RightButton")
F.RunTimers()
expect(F.lastMenu and F.MenuItem(L.CAT_folders) ~= nil and F.MenuItem(L.CAT_macros) == nil,
    "the bar's menu lists the macros, a player's own on the bar, or not the folders")
expect(errors() == 0, "KaLi HUD's own folders err: " .. select(2, errors()))
