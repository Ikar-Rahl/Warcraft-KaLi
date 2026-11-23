-- Folders: elements of the slot hub gathered behind one button, their list opening next to it: icons in a grid, or
-- icons with their text in one line, so many to a line; a separator (UI/Hub/Separators.lua) a rule between its
-- neighbours in their line, across it. Anything goes in: ours, other addons', Blizzard's map widgets, the minimap
-- buttons UI/Hub/Collect.lua takes, other folders (Ikar 2026-11-16: "we will also need folder in folders"), never
-- itself nor one it holds. One comes made, "Add-ons", where other addons' buttons land (Ikar 2026-11-14); others for
-- what KaLi HUD shows (UI/Hub/Seeds.lua), each with its role. Its button, list and contents are laid out by
-- UI/Hub/InfoBar.lua. Its button wears an icon of the library (Data/Icons.lua, picked in UI/Hub/IconPicker.lua) and
-- its name, or its icon alone (Ikar 2026-11-15). It opens and shuts in combat too (Ikar 2026-11-16: "if running a
-- macro is allowed, I don't see why opening a folder would not"): its button and its list are secure frames,
-- Blizzard's handler templates, whose snippets the game runs on the player's click or pointer; laid out out of combat,
-- they hold still during a fight. A folder in a folder opens as a menu's submenu: its list beside the one it stands
-- in, the other lists opened from that one shut, shut with it.
local _, ns = ...

local Folders = {}
ns.Folders = Folders

local Hub, Buttons = ns.Hub, ns.HubButtons
local L = ns.L
local max, min = math.max, math.min

-- Their ids, and the list of them (UI/Hub/Hub.lua's Made, shared with the macros and the separators).
local made = Hub.Made("folders")
-- The folders' own icon, the library's first; the library's white glyphs are drawn in the folders' colour.
local ICON = ns.ICONS[1][1]
Folders.TINT = { 0.95, 0.8, 0.5 }
local WHITE = { 1, 1, 1 }
-- What a folder does when it says nothing of its own.
local DEFAULTS = { style = "icons", flow = "horizontal", perLine = 5, dir = "upleft", open = "click", icon = ICON,
    iconOnly = false }
-- Between the list and its folder; round each icon; between items with their text; a separator's room along its
-- line, its rule in the middle of it.
local GAP, PAD, SPACING, SEP = 3, 3, 10, 9
-- How long the pointer may be off a folder and its list before one that closes on leaving does (the game's auto-hide).
local LEAVE_DELAY = 0.4
local NAME_LETTERS = 40
-- Open, its button is pressed in (HubButtons.Well), its icon a unit down and right; the well this far past its sides.
local WELL_PAD = 4

local panels, objects = {}, {}
-- While our own code shows or hides a list, it isn't the player opening or shutting the folder; while one is dragged,
-- whether it was open.
local quiet = false
local dragOpen = {}
-- DropTarget's answer, one table for all: read it at once.
local hit = {}

local function all()
    return ns.db.folders
end

function Folders.Get(id)
    return all()[id]
end

function Folders.IsFolder(name)
    return all()[name] ~= nil
end

-- Whether a name is a folder's id, saved or not: its button is a secure one (HubButtons.Make).
Folders.IsId = made.IsId

-- One of its settings; which way it opens, unset, its host's for one in a folder (the way that one opens on).
function Folders.Setting(id, key)
    local f = all()[id]
    local v = f and f[key]
    if v == nil and key == "dir" then
        local at, steps = Folders.Host(id), 0
        while at and steps <= #Folders.List() do
            local d = all()[at] and all()[at].dir
            if d ~= nil then
                return d
            end
            at, steps = Folders.Host(at), steps + 1
        end
    end
    if v == nil then
        return DEFAULTS[key]
    end
    return v
end

-- The folder's button as its settings say: its icon, a white glyph in the folders' colour, and its name by it; or its
-- icon alone, or its name alone (Hub.LookOf).
local function dress(o, id)
    local f = all()[id]
    local look = Hub.LookOf(f)
    local icon = Folders.Setting(id, "icon")
    local c = Hub.IsGlyph(icon) and Folders.TINT or WHITE
    o.atlas, o.iconR, o.iconG, o.iconB = look ~= "name" and icon or nil, c[1], c[2], c[3]
    o.label = f and f.name or id
    o.text = look ~= "icon" and o.label or nil
end

-- Its button drawn again, one of those changed.
local function redress(id)
    if objects[id] then
        dress(objects[id], id)
    end
    ns.InfoBar.Update(id)
end

-- Every folder's id, in the order they were made: read it, never change it. The list is taken again when next asked
-- for once told to forget (Hub.Changed: saved data changed under it).
Folders.List, Folders.Forget = made.List, made.Forget

-- The folder other addons' new buttons land in, if any.
function Folders.Default()
    for _, id in ipairs(Folders.List()) do
        if all()[id].default then
            return id
        end
    end
end

function Folders.SetDefault(id, on)
    for _, f in pairs(all()) do
        f.default = nil
    end
    if on and all()[id] then
        all()[id].default = true
    end
    Hub.Changed()
end

-- The folder where what doesn't fit on the bar goes, if any (its `overflow`; UI/Hub/InfoBar.lua's fit): one at the
-- most, as the one where new addons land.
function Folders.Overflow()
    for _, id in ipairs(Folders.List()) do
        if all()[id].overflow then
            return id
        end
    end
end

function Folders.SetOverflow(id, on)
    for _, f in pairs(all()) do
        f.overflow = nil
    end
    if on and all()[id] then
        all()[id].overflow = true
    end
    Hub.Changed()
end

local clean = Hub.CleanName

-- The folder made for a role (UI/Hub/Seeds.lua: the weapon skills', the statistics'...), where the items made for it
-- stand by default (their obj.home); nil once deleted.
function Folders.ByRole(role)
    for _, id in ipairs(Folders.List()) do
        if all()[id].role == role then
            return id
        end
    end
end

-- The folder folder `id` stands in, if any.
function Folders.Host(id)
    local e = Hub.Entry(id)
    return e and e.side == "folder" and e.folder or nil
end

-- Whether folder `id` stands in folder `outer`, or in a folder that does, however deep.
function Folders.Within(id, outer)
    local at, steps = Folders.Host(id), 0
    while at and steps <= #Folders.List() do
        if at == outer then
            return true
        end
        at, steps = Folders.Host(at), steps + 1
    end
    return false
end

-- Whether `name` may go into folder `id`: anything, a folder but itself and those it holds; nothing into a locked one
-- (UI/Hub/Seeds.lua), whose contents are the code's.
function Folders.CanHold(id, name)
    return all()[id] ~= nil and name ~= id and not (Folders.IsFolder(name) and Folders.Within(id, name))
        and not ns.Seeds.IsLockedFolder(id)
end

-- How many folders folder `id` stands in, one in another.
local function depth(id)
    local n, at = 0, Folders.Host(id)
    while at and n <= #Folders.List() do
        n, at = n + 1, Folders.Host(at)
    end
    return n
end

-- Every folder's id, those standing in none first, each before those it holds (laid out after it, beside it).
function Folders.Ordered()
    local list, deep = {}, {}
    for _, id in ipairs(Folders.List()) do
        list[#list + 1] = id
        deep[id] = depth(id)
    end
    table.sort(list, function(a, b)
        if deep[a] ~= deep[b] then
            return deep[a] < deep[b]
        end
        return made.Number(a) < made.Number(b)
    end)
    return list
end

-- A new folder named `name`, made for `role` if given; its id. Where it stands is the hub's.
function Folders.Create(name, default, role)
    local id = made.NewId()
    all()[id] = { name = clean(name) or L.FOLDER_NEW, role = role }
    objects[id] = nil
    made.Forget()
    if default then
        Folders.SetDefault(id, true)
    end
    return id
end

-- Renamed, a folder made by KaLi HUD is the player's: its role gone; what's made for it stays in it, saved there where
-- it stood by default (by its role, obj.home). A locked one is never renamed (its menu has no entry for it).
function Folders.Rename(id, name)
    local f = all()[id]
    name = clean(name)
    if f and name and name ~= f.name then
        if f.role then
            for _, e in ipairs(Hub.InFolder(id)) do
                if not Hub.Saved(e.name) then
                    Hub.PlaceAt(e.name, "folder", e.order, id)
                end
            end
        end
        f.name, f.role = name, nil
        redress(id)
        Hub.Changed()
    end
end

-- Its icon, one of the library's: the folders' own stays unsaved.
function Folders.SetIcon(id, atlas)
    local f = all()[id]
    if f then
        f.icon = atlas ~= ICON and atlas or nil
        redress(id)
    end
end

-- Its icon alone on its button, or its name by it.
function Folders.SetIconOnly(id, on)
    Folders.SetLook(id, on and "icon" or "both")
end

-- Its icon and name, its icon alone or its name alone (Hub.LOOKS).
function Folders.SetLook(id, look)
    local f = all()[id]
    if f then
        Hub.SetLook(f, look)
        redress(id)
    end
end

-- A folder no more (deleted, or its making undone): its list shut, its icon library closed.
function Folders.Gone(id)
    objects[id], dragOpen[id] = nil, nil
    made.Forget()
    if panels[id] then
        panels[id]:Hide()
    end
    ns.IconPicker.Close(id)
end

-- Its saved data changed under it (UI/Hub/History.lua): drawn as it says, or gone.
function Folders.Refresh(id)
    if all()[id] then
        made.Forget()
        redress(id)
    else
        Folders.Gone(id)
    end
end

-- Gone with all it holds (Ikar 2026-11-16: "the content will be deleted, not displaced"): the folders, macros and
-- separators in it deleted, however deep; what can't be (ours, the folders KaLi HUD makes, which are only ever taken
-- off the HUD, other addons', Blizzard's widgets) hidden, out of any folder; a hidden one forgets the way back into it.
-- Not during a fight.
function Folders.Delete(id)
    if not all()[id] or InCombatLockdown() then
        return
    end
    for _, e in ipairs(Hub.InFolder(id)) do
        if e.isFolder and not ns.Seeds.FolderSpec(e.name) then
            Folders.Delete(e.name)
        elseif e.isMacro then
            ns.Macros.Delete(e.name)
        elseif e.isSeparator then
            ns.Separators.Drop(e.name)
        else
            Hub.OutOfFolder(e.name, true)
        end
    end
    -- those saved in it that aren't drawn (ours another character has), and the hidden whose way back it was
    for name, item in Hub.EachSaved() do
        if item.folder == id then
            if ns.Separators.IsId(name) then
                ns.Separators.Drop(name)
            else
                Hub.OutOfFolder(name)
            end
        end
    end
    local took = all()[id].overflow
    all()[id] = nil
    Hub.Unplace(id)
    -- the folder that took what doesn't fit on the bar: « Suite » takes it again, while there is one, so that a
    -- deletion that said nothing of it doesn't leave what doesn't fit with nowhere to show
    if took then
        for _, f in pairs(all()) do
            if f.role == "overflow" then
                f.overflow = true
                break
            end
        end
    end
    Folders.Gone(id)
    Hub.Changed()
end

-- Only `id` open, with those it stands in: the others shut, as a click does (ONE_OPEN).
local function onlyOpen(id)
    for other, f in pairs(all()) do
        if other ~= id and f.opened and not Folders.Within(id, other) then
            f.opened = nil
        end
    end
end

-- At login. The first time (a new install): "Add-ons" at the bar's right end, where other addons' buttons land. One
-- that closes on leaving starts shut.
function Folders.Setup()
    if ns.dbInfo.firstRun and not next(all()) then
        local id = Folders.Create(L.FOLDER_ADDONS, true, "addons")
        Hub.PlaceAt(id, "right", 5)
        Hub.Changed()
    end
    for id, f in pairs(all()) do
        if f.opened and Folders.Setting(id, "open") ~= "click" then
            Folders.SetOpen(id, false)
        end
    end
end

-- ---------- Opening ----------

-- Its secure button's snippets (Folders.Wire), run by the game: a left click shows or hides the list; one opening on
-- hover shows it as the pointer comes on the button; one closing on leaving (or opening on hover) registers it with
-- the game's auto-hide, the button with it, so it shuts once the pointer has been off both for LEAVE_DELAY. The
-- list's own, as it shows or hides however that came: telling our code (CallMethod, which Blizzard runs insecurely and
-- apart).
-- One folder open at a time (Ikar 2026-11-16: "only one folder open at a time, opening another close the previous"):
-- opening its list (`list`) shuts every other open one (the registry's "panel" refs, Folders.Layout) but those its
-- button stands in, however far out (its "kali-in", the list it stands in its "up" ref, that list's button its
-- "owner"); those shut take the ones opened from them along (ON_HIDE). Each way out at most as many steps as there are
-- folders: a folder in itself, which nothing makes, mustn't hold the game in a snippet.
local ONE_OPEN = [[
    local all = self:GetFrameRef("all")
    local count = all and all:GetAttribute("kali-count") or 0
    for i = 1, count do
        local other = all:GetFrameRef("panel" .. i)
        if other and other ~= list and other:IsShown() then
            local outer, b, steps = false, self, 0
            while b and b:GetAttribute("kali-in") and steps < count do
                steps = steps + 1
                local host = b:GetFrameRef("up")
                if not host then
                    break
                elseif host == other then
                    outer = true
                    break
                end
                b = host:GetFrameRef("owner")
            end
            if not outer then
                other:Hide()
            end
        end
    end
]]
-- Each list its button stands in, however far out, that shuts on leaving: registered again with the game's
-- auto-hide (SecureHoverDriver: a set of rects taken at once), its button and every list opened inward from it down
-- to this one in it, the pointer there keeping it open.
local INWARD = [[
    if self:GetAttribute("kali-in") then
        local up, steps = self:GetFrameRef("up"), 0
        while up and steps < count do
            steps = steps + 1
            local owner = up:GetFrameRef("owner")
            local delay = owner and (owner:GetAttribute("kali-leave")
                or PlayerInCombat() and owner:GetAttribute("kali-fight-leave"))
            if delay and up:IsShown() then
                up:RegisterAutoHide(delay)
                up:AddToAutoHide(owner)
                local inner, by, hops = list, self, 0
                while inner and by and hops < count do
                    hops = hops + 1
                    up:AddToAutoHide(inner)
                    local host = by:GetAttribute("kali-in") and by:GetFrameRef("up")
                    if not host or host == up then
                        break
                    end
                    inner, by = host, host:GetFrameRef("owner")
                end
            end
            up = owner and owner:GetAttribute("kali-in") and owner:GetFrameRef("up") or nil
        end
    end
]]
local ON_CLICK = [[
    if button ~= "LeftButton" then
        return
    end
    local list = self:GetFrameRef("list")
    if not list then
        return
    end
    if list:IsShown() then
        list:Hide()
    else
        list:Show()
        local delay = self:GetAttribute("kali-leave") or PlayerInCombat() and self:GetAttribute("kali-fight-leave")
        if delay then
            list:RegisterAutoHide(delay)
            list:AddToAutoHide(self)
        end
]] .. ONE_OPEN .. INWARD .. [[
    end
]]
local ON_ENTER = [[
    if not self:GetAttribute("kali-hover") then
        return
    end
    local list = self:GetFrameRef("list")
    if list then
        list:Show()
        list:RegisterAutoHide(self:GetAttribute("kali-leave"))
        list:AddToAutoHide(self)
]] .. ONE_OPEN .. INWARD .. [[
    end
]]
local ON_SHOW = [[
    self:CallMethod("KaLiShownOrHidden")
]]
-- A list shutting shuts those opened from it (its "sub" refs), their own after them.
local ON_HIDE = [[
    local n = self:GetAttribute("kali-subs") or 0
    for i = 1, n do
        local sub = self:GetFrameRef("sub" .. i)
        if sub then
            sub:Hide()
        end
    end
    self:CallMethod("KaLiShownOrHidden")
]]

function Folders.IsOpen(id)
    local f = all()[id]
    return f ~= nil and f.opened == true
end

-- Its list shown or hidden by our code (the layout, a drag), which isn't the folder opening or shutting.
local function showList(p, shown)
    quiet = true
    p:SetShown(shown)
    quiet = false
end

-- The player opened or shut it (a click, the pointer, the game's auto-hide), in combat too: it's open while its list
-- shows, its button pressed in while so.
local function shownOrHidden(id)
    local f, p = all()[id], panels[id]
    if quiet or not (f and p) then
        return
    end
    local open = p:IsShown() or nil
    if f.opened == open then
        return
    end
    f.opened = open
    local b = Buttons.Get(id)
    if b and b.kaliWell then
        Folders.Press(b, open == true)
    end
    -- its members' handles: the next layout, once the fight is over
    ns.InfoBar.Request()
end

-- Opened or shut by our code (a menu, at login): drawn so at the next layout; none during a fight.
function Folders.SetOpen(id, open)
    local f = all()[id]
    open = open and true or nil
    if not f or f.opened == open or InCombatLockdown() then
        return
    end
    f.opened = open
    if open then
        onlyOpen(id)
    end
    ns.InfoBar.Request()
end

-- Its list hidden while it's dragged (out of combat), whether it was open kept for after.
function Folders.HidePanel(id)
    local p = panels[id]
    if p then
        dragOpen[id] = Folders.IsOpen(id)
        UnregisterAutoHide(p)
        p.hideAt = nil
        showList(p, false)
    end
end

-- The click that ended its drag: its handler opened or shut its list, which goes back as it was before the drag.
function Folders.AfterDrag(id)
    local f = all()[id]
    if f and dragOpen[id] ~= nil and not InCombatLockdown() then
        f.opened = dragOpen[id] or nil
        ns.InfoBar.Request()
    end
    dragOpen[id] = nil
end

-- While anything is dragged, the open lists stay open (one may be where it's dropped): out of the game's auto-hide
-- until the next layout puts them back in.
function Folders.HoldOpen()
    for _, p in pairs(panels) do
        if p:IsShown() then
            UnregisterAutoHide(p)
            p.hideAt = nil
        end
    end
end

-- Its button told how it opens: on hover, and whether it closes on leaving (out of combat).
-- In a fight, one opening on a click closes once left too while the option says so ("kali-fight-leave"; Ikar
-- 2026-11-16: "always auto close in combat. make it an option, on by default"): the snippets ask PlayerInCombat().
local function arm(b, id)
    local mode = Folders.Setting(id, "open")
    local leave = mode ~= "click" and LEAVE_DELAY or nil
    local hover = mode == "hover" or nil
    local fight = ns.db.options.folderCombatClose and LEAVE_DELAY or nil
    if b:GetAttribute("kali-leave") ~= leave then
        b:SetAttribute("kali-leave", leave)
    end
    if b:GetAttribute("kali-hover") ~= hover then
        b:SetAttribute("kali-hover", hover)
    end
    if b:GetAttribute("kali-fight-leave") ~= fight then
        b:SetAttribute("kali-fight-leave", fight)
    end
end

-- As a fight starts (PLAYER_REGEN_DISABLED, the lockdown not on yet): one open on a click registered with the game's
-- auto-hide, its button and the lists open inward from it, to shut once the pointer has been on it and left it; as it
-- ends, back to staying open (one opened in the fight too).
local function fightStarts()
    if not ns.db.options.folderCombatClose or InCombatLockdown() then
        return
    end
    for _, id in ipairs(Folders.Ordered()) do
        local p, b = panels[id], Buttons.Get(id)
        if p and b and p:IsShown() and Folders.Setting(id, "open") == "click" then
            RegisterAutoHide(p, LEAVE_DELAY)
            AddToAutoHide(p, b)
            for _, inner in ipairs(Folders.List()) do
                local ip = panels[inner]
                if ip and ip:IsShown() and Folders.Within(inner, id) then
                    AddToAutoHide(p, ip)
                end
            end
        end
    end
end
-- Again after a layout done as the fight starts (UI/Hub/InfoBar.lua's: the padlock shut for it), which puts the
-- lists back where they stand: the game drops from its auto-hide a list that was placed anew.
Folders.FightStarts = fightStarts

local function fightEnds()
    if InCombatLockdown() then
        return
    end
    for id, p in pairs(panels) do
        if Folders.Setting(id, "open") == "click" and p:IsShown() then
            UnregisterAutoHide(p)
            p.hideAt = nil
        end
    end
end

-- A press of the mouse anywhere but on an open list shuts the open lists (Ikar 2026-11-17: "when opening a menu, a click
-- outside should close it, regardless of the rules"), however each opens (a click, a click shutting once left, the
-- pointer): those the pointer is on stay, with those they stand in, as a menu's submenus do. A press on a folder's
-- button is its own click's, which opens or shuts it and shuts the others (ONE_OPEN); one on our editor, our icon
-- library or a question of the game's (a rename, a deletion) is theirs; one while a menu of the game's is open shuts
-- that menu first, as the game's own stacked menus do. Not in a fight, when the game lets no addon hide a secure list:
-- its own rule shuts one once the pointer has left it then (folderCombatClose).
local OURS_OVER = { "KaLiHUDMacroEditor", "KaLiHUDIconPicker", "StaticPopup1", "StaticPopup2", "StaticPopup3",
    "StaticPopup4" }
local function pressed()
    if InCombatLockdown() or ns.HubDrag.Current() then
        return
    end
    local open = {}
    for id, p in pairs(panels) do
        if p:IsShown() then
            open[#open + 1] = id
        end
    end
    if #open == 0 then
        return
    end
    local manager = type(Menu) == "table" and Menu.GetManager and Menu.GetManager()
    if manager and manager.IsAnyMenuOpen and manager:IsAnyMenuOpen() then
        return
    end
    for _, id in ipairs(Folders.List()) do
        local b = Buttons.Get(id)
        if b and b:IsVisible() and b:IsMouseOver() then
            return
        end
    end
    for _, name in ipairs(OURS_OVER) do
        local f = _G[name]
        if type(f) == "table" and f.IsVisible and f:IsVisible() and f:IsMouseOver() then
            return
        end
    end
    local keep = {}
    for _, id in ipairs(open) do
        if panels[id]:IsMouseOver() then
            local at, steps = id, 0
            while at and not keep[at] and steps <= #Folders.List() do
                keep[at], at, steps = true, Folders.Host(at), steps + 1
            end
        end
    end
    for _, id in ipairs(open) do
        if not keep[id] then
            Folders.SetOpen(id, false)
        end
    end
end
ns.On("GLOBAL_MOUSE_DOWN", function()
    ns.SafeCall(pressed)
end)

ns.On("PLAYER_REGEN_DISABLED", function()
    ns.SafeCall(fightStarts)
end)
ns.On("PLAYER_REGEN_ENABLED", function()
    ns.SafeCall(fightEnds)
end)

-- ---------- Naming and settings ----------

local function editBoxOf(dialog)
    return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

-- Asks a folder's name, `current` filled in; done(name) once given. Another's (a separator's title): `ask` the
-- question, `blank` taking a blank answer too (done("")).
function Folders.AskName(current, done, ask, blank)
    StaticPopupDialogs.KALIHUD_FOLDER_NAME = StaticPopupDialogs.KALIHUD_FOLDER_NAME or {
        button1 = ns.G("ACCEPT", "Accepter"),
        button2 = ns.G("CANCEL", "Annuler"),
        hasEditBox = 1,
        maxLetters = NAME_LETTERS,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        -- what the game calls of ours, under the handlers' guard (ns.Guarded)
        OnShow = ns.Guarded(function(dialog, data)
            local box = editBoxOf(dialog)
            if box then
                box:SetText(data and data.name or "")
                box:HighlightText()
            end
        end),
        OnAccept = ns.Guarded(function(dialog, data)
            local box = editBoxOf(dialog)
            data.done(box and box:GetText())
        end),
        EditBoxOnEnterPressed = ns.Guarded(function(box, data)
            data.done(box:GetText())
            box:GetParent():Hide()
        end),
        EditBoxOnEscapePressed = ns.Guarded(function(box)
            box:GetParent():Hide()
        end),
    }
    StaticPopupDialogs.KALIHUD_FOLDER_NAME.text = ask or L.FOLDER_NAME_ASK
    StaticPopup_Show("KALIHUD_FOLDER_NAME", nil, nil, { name = current, done = function(text)
        local name = clean(text)
        if name or blank then
            ns.SafeCall(done, name or "")
        end
    end })
end

-- Asked first, the question saying what goes with it (Ikar 2026-11-16: "prompt the user if he is sure, as the content
-- will be deleted, not displaced"); undone from the bar's menu (UI/Hub/History.lua).
function Folders.AskDelete(id)
    local f = all()[id]
    if not f then
        return
    end
    StaticPopupDialogs.KALIHUD_FOLDER_DELETE = StaticPopupDialogs.KALIHUD_FOLDER_DELETE or {
        button1 = ns.G("YES", "Oui"),
        button2 = ns.G("NO", "Non"),
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = ns.Guarded(function(_, data)
            ns.History.Do("delete", data, Folders.Delete, data)
        end),
    }
    StaticPopupDialogs.KALIHUD_FOLDER_DELETE.text = #Hub.InFolder(id) > 0 and L.FOLDER_DELETE_ASK
        or L.FOLDER_DELETE_EMPTY_ASK
    StaticPopup_Show("KALIHUD_FOLDER_DELETE", f.name, nil, id)
end

-- The icon library next to the folder's button, its list shut not to lie under it; a pick changes its icon at once.
function Folders.PickIcon(id)
    local f = all()[id]
    if not f then
        return
    end
    Folders.SetOpen(id, false)
    ns.IconPicker.Open(id, Buttons.Get(id), f.name, Folders.Setting(id, "icon"), function(atlas)
        Folders.SetIcon(id, atlas)
    end)
end

-- What its list shows: icons alone or with their text (`styles`, its radios), then, for a list with text, two boxes
-- (Ikar 2026-11-20, the sketch of the attributes): the values set apart and aligned on the list's right, and those
-- that say nothing in grey (0, 0 %, « Aucun »). Any folder's, the player's own as those made with KaLi HUD.
function Folders.ShowEntries(id, styles)
    local entries = styles
    entries[#entries + 1] = { divider = true }
    for _, key in ipairs({ "align", "dim" }) do
        entries[#entries + 1] = { text = L["FOLDER_" .. string.upper(key)], held = true,
            tooltip = L["FOLDER_" .. string.upper(key) .. "_TIP"], checked = function()
                return all()[id] ~= nil and all()[id][key] == true
            end, func = function()
                local f = all()[id]
                if f then
                    f[key] = not f[key] or nil
                end
            end }
    end
    return entries
end

-- What its list does with its members' texts: each value set apart and aligned on its right, those that say nothing
-- in grey, texts alone without their icons (its style "names"); nil for a list of icons alone, or one doing none.
function Folders.Values(id)
    local f = all()[id]
    local style = Folders.Setting(id, "style")
    if not f or style == "icons" or not (f.align or f.dim or style == "names") then
        return nil
    end
    return { align = f.align == true, dim = f.dim == true, names = style == "names" }
end

-- The folder's settings, as the hub's menus take them.
function Folders.Menu(id)
    local function radios(key, values, label)
        local list = {}
        for _, v in ipairs(values) do
            list[#list + 1] = {
                text = label(v),
                radio = true,
                held = true,
                checked = function()
                    return Folders.Setting(id, key) == v
                end,
                func = function()
                    local f = all()[id]
                    if f then
                        -- the default kept too by one in a folder, whose unset way is its host's
                        f[key] = (v ~= DEFAULTS[key] or key == "dir" and Folders.Host(id)) and v or nil
                    end
                end,
            }
        end
        return list
    end
    local function named(prefix)
        return function(v)
            return L[prefix .. v]
        end
    end
    -- A locked one (UI/Hub/Seeds.lua) is only taken off the HUD whole, as what isn't ours to destroy: deleted, it
    -- couldn't be had back (Ikar 2026-11-20: "built in folder, when deleted, shoudl only be deselected, otherwise, they
    -- are unrecoverable"); the bar's menu, under « Dossiers », shows it again where it was. Nothing else of it changes
    -- (Ikar 2026-11-23: "No edit, no reset"): what its menu says first is why, and that a drag takes a copy out.
    if ns.Seeds.IsLockedFolder(id) then
        return {
            { title = L.TYPE_LOCKED_FOLDER },
            { text = L.FOLDER_LOCKED_DRAG, disabled = true, tooltip = L.FOLDER_LOCKED_TIP },
            { divider = true },
            { text = L.ITEM_REMOVE, held = true, tooltip = L.DELETE_HIDES_TIP, func = function()
                Folders.SetOpen(id, false)
                ns.History.Do("hide", id, Hub.SetShown, id, false)
            end },
        }
    end
    -- each held during a fight, as all that changes how the folder or its list stands (UI/Hub/Menus.lua)
    local bundled = ns.Seeds.FolderSpec(id) ~= nil
    local entries = {
        { text = L.FOLDER_RENAME, held = true, func = function()
            Folders.AskName(all()[id] and all()[id].name, function(name)
                ns.History.Do("rename", id, Folders.Rename, id, name)
            end)
        end },
        { text = L.FOLDER_ICON, held = true, func = function()
            Folders.PickIcon(id)
        end },
        Hub.LookEntry(function()
            return all()[id]
        end, function(look)
            Folders.SetLook(id, look)
        end),
    }
    -- How its list stands, in a submenu of its own, « Liste » (the review of 2026-11-20: some sixteen entries in the
    -- folder's menu): its look, apart from its button's above (Ikar 2026-11-20: "you also have 2 affichage in folder
    -- option, and the second has none for name only"), its flow, as many to a line, the way it opens, how.
    local list = {
        { text = L.FOLDER_SHOW, held = true, items = Folders.ShowEntries(id, radios("style", { "icons", "text", "names" },
            named("FOLDER_STYLE_"))) },
        { text = L.FOLDER_FLOW, held = true, items = radios("flow", { "horizontal", "vertical" }, named("FOLDER_FLOW_")) },
    }
    entries[#entries + 1] = { text = L.FOLDER_LIST, held = true, items = list }
    -- icons or their text, as many to a line, a column when the list runs down and so named (the review of
    -- 2026-11-20): a slider (Ikar 2026-11-20: "Ça doit être un slider avec la limite max à 25"), the list laid out again
    -- as it moves
    local column = Folders.Setting(id, "flow") == "vertical"
    list[#list + 1] = { text = column and L.FOLDER_PER_COLUMN or L.FOLDER_PER_LINE, held = true, items = { { held = true, slider = {
        min = ns.DB.PER_LINE[1], max = ns.DB.PER_LINE[2],
        get = function()
            return Folders.Setting(id, "perLine")
        end,
        set = function(n)
            local f = all()[id]
            if f then
                f.perLine = n ~= DEFAULTS.perLine and n or nil
            end
        end,
    } } } }
    list[#list + 1] = { text = L.FOLDER_DIR, held = true,
        items = radios("dir", { "upleft", "upright", "downleft", "downright" }, named("FOLDER_DIR_")) }
    list[#list + 1] = { text = L.FOLDER_OPEN, held = true,
        items = radios("open", { "click", "leave", "hover" }, named("FOLDER_OPEN_")) }
    entries[#entries + 1] = { text = L.FOLDER_DEFAULT, held = true, checked = function()
        return all()[id] ~= nil and all()[id].default == true
    end, func = function()
        Folders.SetDefault(id, not (all()[id] and all()[id].default))
    end }
    entries[#entries + 1] = { text = L.FOLDER_OVERFLOW_HERE, held = true, tooltip = L.FOLDER_OVERFLOW_TIP, checked = function()
        return all()[id] ~= nil and all()[id].overflow == true
    end, func = function()
        Folders.SetOverflow(id, not (all()[id] and all()[id].overflow))
    end }
    entries[#entries + 1] = { divider = true }
    entries[#entries + 1] = { text = L.SEPARATOR_ADD, held = true, func = function()
        ns.Separators.Create(id)
    end }
    entries[#entries + 1] = { text = L.MACRO_CREATE, held = true, func = function()
        ns.Macros.New(id)
    end }
    entries[#entries + 1] = { text = L.NOTE_CREATE, held = true, func = function()
        ns.Macros.New(id, nil, true)
    end }
    entries[#entries + 1] = ns.Macros.PasteEntry(id)
    entries[#entries + 1] = { divider = true }
    -- « Add-ons » and « Suite », made by KaLi HUD, are taken off the HUD as the locked ones; the player's own is
    -- deleted, asked first.
    if bundled then
        entries[#entries + 1] = { text = L.ITEM_REMOVE, held = true, tooltip = L.DELETE_HIDES_TIP, func = function()
            Folders.SetOpen(id, false)
            ns.History.Do("hide", id, Hub.SetShown, id, false)
        end }
    else
        entries[#entries + 1] = { text = L.FOLDER_DELETE, held = true, func = function()
            Folders.AskDelete(id)
        end }
    end
    return entries
end

-- The folder as an element of the hub: its icon and its name.
function Folders.Object(id)
    local o = objects[id]
    if not o then
        o = { type = "data source", isFolder = true }
        o.OnClick = function(_, button)
            -- its secure handler opened or shut the list (Folders.Wire), a click only sounding: opening on hover or
            -- shutting on leaving stays silent
            if button == "LeftButton" then
                ns.PlaySoundOf(ns.FOLDER_SOUNDS, ns.db.options.folderSound, Folders.IsOpen(id))
            end
        end
        o.menu = function()
            return Folders.Menu(id)
        end
        objects[id] = o
    end
    dress(o, id)
    return o
end

-- The folder's button pressed in while open, round its icon and name; out again once shut. Its well is made with the
-- button, out of combat. During a fight the well shows or hides alone: what a secure button holds is placed out of
-- combat (inferred, unverified in game), the icon's unit down and right waiting for the next layout.
function Folders.Press(b, on)
    if not InCombatLockdown() then
        local floor, half = b.kaliWell.floor, Hub.IconSize() / 2 + Buttons.WELL_DEPTH
        floor:ClearAllPoints()
        floor:SetPoint("TOPLEFT", b, "LEFT", -WELL_PAD, half)
        floor:SetPoint("BOTTOMRIGHT", b, "RIGHT", WELL_PAD, -half)
        -- HubButtons.Fill sets the icon at one of these: set again here, it never drifts
        local point = b.Icon:GetPoint(1)
        if point == "LEFT" or point == "CENTER" then
            local d = on and 1 or 0
            b.Icon:SetPoint(point, b, point, d, -d)
        end
    end
    Buttons.ShowWell(b.kaliWell, on)
    b.pressed = on
end

-- ---------- The list ----------

-- How far in from the list's edge its contents start: past the thin border's metal.
local function inset()
    local prof = ns.Border.Profile(true)
    return max(0, prof.e - prof.out) + 2
end
Folders.Inset = inset

-- A secure frame holding every folder's list, its "panel" refs by their place among the folders and their count
-- ("kali-count"), set out of combat (Folders.Layout): a button's snippet shuts the others through it (ONE_OPEN).
local registryFrame
local function registry()
    if not registryFrame then
        registryFrame = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    end
    return registryFrame
end

-- Its list: a secure frame (SecureHandlerShowHideTemplate), which the button's snippets may show and hide in combat,
-- and which tells our code each time (shownOrHidden).
local function panel(id)
    local p = panels[id]
    if p then
        return p
    end
    p = CreateFrame("Frame", nil, UIParent, "SecureHandlerShowHideTemplate")
    p:Hide()
    p:SetFrameStrata("HIGH")
    p:SetFrameLevel(40)
    p:EnableMouse(true)
    -- a secure frame passes clicks on to what's under it; the list takes them, as a plain one did
    p:SetPropagateMouseClicks(false)
    p.labels, p.cells = {}, {}
    p.Empty = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.Empty:SetTextColor(0.5, 0.5, 0.5)
    p.Empty:SetPoint("CENTER")
    p.KaLiShownOrHidden = function()
        ns.SafeCall(shownOrHidden, id)
    end
    p:SetAttribute("_onshow", ON_SHOW)
    p:SetAttribute("_onhide", ON_HIDE)
    ns.Border.Attach(p, { level = 1 })
    -- its floor the info bar's carved channel's, whether the bar is carved or not (Ikar 2026-11-16: "the menu
    -- background should match the darkened version of the bottom bar, even if she is not darkened")
    local c = ns.Plate.CHANNEL
    p.Floor = p:CreateTexture(nil, "BACKGROUND", nil, -6)
    p.Floor:SetColorTexture(c[1], c[2], c[3], c[4])
    p.Floor:SetAllPoints(p.KaLiBorder.Bg)
    panels[id] = p
    return p
end

-- A folder's new secure button (HubButtons.Make, out of combat): its list, the snippets that open it, its well.
function Folders.Wire(b, id)
    local p = panel(id)
    SecureHandlerSetFrameRef(b, "list", p)
    SecureHandlerSetFrameRef(p, "owner", b)
    SecureHandlerSetFrameRef(b, "all", registry())
    b:SetAttribute("_onclick", ON_CLICK)
    b:SetAttribute("_onenter", ON_ENTER)
    arm(b, id)
    b.kaliWell = Buttons.Well(b)
    Buttons.ShowWell(b.kaliWell, false)
end

function Folders.Panel(id)
    return panels[id]
end

-- The open list a button stands in (its parent while there), nil for one on the bar: what a stat's card kept open
-- stacks over (UI/Hub/Infos/StatCard.lua).
function Folders.ListOf(button)
    local parent = button and button.GetParent and button:GetParent()
    for _, p in pairs(panels) do
        if p == parent then
            return p:IsShown() and p or nil
        end
    end
    return nil
end

local function label(p, i)
    local fs = p.labels[i]
    if not fs then
        fs = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetWordWrap(false)
        p.labels[i] = fs
    end
    Buttons.SizeText(fs)
    fs:SetTextColor(0.88, 0.88, 0.88)
    return fs
end

-- What shows in the list, each { e, w, b (ours), label (with text), sep, title, starts, nameW, valueW }: ours as
-- buttons filled for it (`values`, what the list does with them: Folders.Values), Blizzard's widgets that can show,
-- other addons' map buttons their addon shows, the separators as buttons their line is drawn on, a named one's title
-- drawn when `titled` (a list with text running down). Returns it and how many labels it took.
local function measure(p, members, icons, cell, level, titled, values)
    local S, drag = Hub.IconSize(), ns.HubDrag.Current()
    local shown, labels = {}, 0
    for _, e in ipairs(members) do
        local m = { e = e }
        if e.isSeparator then
            local b = Buttons.Make(e.name)
            b.slotSide = "folder"
            if e.name ~= drag then
                b:SetParent(p)
                b:SetFrameStrata(p:GetFrameStrata())
                b:SetFrameLevel(level)
            end
            m.b, m.sep, m.w = b, true, 0
            m.starts = ns.Separators.StartsLine(e.name)
            m.title = titled and ns.Separators.Name(e.name) or nil
            if m.title then
                m.w = Buttons.TitleWidth(b, m.title)
            end
        elseif e.native then
            if ns.Natives.Size(e.name, true) > 0 then
                m.w = S
            end
        elseif e.foreign then
            if ns.Collect.Shown(e.name) then
                m.w = S
            else
                Buttons.PlaceHandle(e.name, nil)
            end
        else
            local b = Buttons.Make(e.name)
            b.slotSide = "folder"
            if e.name ~= drag then
                b:SetParent(p)
                b:SetFrameStrata(p:GetFrameStrata())
                b:SetFrameLevel(level)
            end
            m.b = b
            b._alignW = nil
            m.w = Buttons.SafeFill(b, e.obj, cell, icons, true, values)
            m.nameW, m.valueW = b._nameW, b._valueW
            -- drawn with no icon (an attribute, a weapon skill): its text alone
            m.bare = not icons and b._mode == "text"
        end
        if m.w and not icons and not m.b then
            labels = labels + 1
            m.label = label(p, labels)
            m.label:SetText(Hub.Label(e.name, e.obj))
            m.w = S + 3 + m.label:GetStringWidth()
        end
        if m.w then
            shown[#shown + 1] = m
        end
    end
    return shown, labels
end

-- The list's members in lines of `per`, icons or with their text (Ikar 2026-11-16: "let's add column even for text,
-- same as icon only"): a line is a row when the list runs across, a column when it runs down. A separator stands in
-- its line between its neighbours, a rule across it, and counts not (Ikar: "separators, I thought about horizontal,
-- not vertical, vertical there is no need, max number should handle them, and vice versa for horizontal folders"):
-- one after a full line ends it. One that starts a line (Separators.StartsLine) begins the next, whatever the count;
-- a title (a named one, drawn) goes with what follows it, to the next line after a full one, as tall as a member.
-- Each line { items (its members in order, separators among them), n (but them), along, thick, values (a column's
-- names' and values' room, its values set apart) }: how long it runs and how thick it stands. Returns the lines and
-- the contents' size along and across.
local function linesOf(shown, icons, flow, per, cell)
    local lines = { { items = {}, n = 0 } }
    local function room(m)
        return m.title and cell or SEP
    end
    for _, m in ipairs(shown) do
        local line = lines[#lines]
        local full = line.n >= per
        if #line.items > 0 and (m.sep and (m.starts or (m.title and full)) or not m.sep and full) then
            line = { items = {}, n = 0 }
            lines[#lines + 1] = line
        end
        line.items[#line.items + 1] = m
        if not m.sep then
            line.n = line.n + 1
        end
    end
    local along, thick = 0, 0
    for _, line in ipairs(lines) do
        local seps = #line.items - line.n
        if icons then
            line.along, line.thick = line.n * cell + seps * SEP, cell
        elseif flow == "horizontal" then
            local sum = 0
            for _, m in ipairs(line.items) do
                sum = sum + (m.sep and SEP or m.w)
            end
            line.along, line.thick = sum + (#line.items - 1) * SPACING + 2 * PAD, cell
        else
            -- a column with icons in it: the texts of those without one start where the others' do, past an icon's room
            local pictured, bare = false, false
            for _, m in ipairs(line.items) do
                if m.bare then
                    bare = true
                elseif not m.sep then
                    pictured = true
                end
            end
            line.indent = (pictured and bare) and (cell - 2 * PAD + 3) or 0
            -- its values set apart: the column as wide as its longest name and its longest value, the values on its
            -- right (Folders.Values)
            local widest, names, values, along = 0, 0, 0, 0
            for _, m in ipairs(line.items) do
                along = along + (m.sep and room(m) or cell)
                if m.title then
                    widest = max(widest, m.w)
                elseif not m.sep then
                    widest = max(widest, m.w + (m.bare and line.indent or 0))
                    if m.valueW then
                        names, values = max(names, m.nameW + (m.bare and line.indent or 0)), max(values, m.valueW)
                    end
                end
            end
            if values > 0 then
                widest = max(widest, names + Buttons.VALUE_GAP + values)
                line.values = true
            end
            line.along, line.thick = along, max(widest + 2 * PAD, cell)
        end
        along, thick = max(along, line.along), thick + line.thick
    end
    return lines, max(along, cell), thick
end

-- One of its members' content changed during a fight, when nothing may be laid out: its button drawn again in place
-- (none of the secure ones, which wait).
function Folders.Refill(id, name)
    local b, e = Buttons.Get(name), Hub.Entry(name)
    if b and e and not b.secure then
        Buttons.SafeFill(b, e.obj, Hub.IconSize() + 2 * PAD, Folders.Setting(id, "style") == "icons", true,
            Folders.Values(id))
    end
end

-- Where a list `pw` wide and `ph` high opens from button `owner`, where InfoBar put it, `dir` its way (Folders.Setting's
-- "dir"): away from the button, its side flush with the button's, kept on the screen. One in folder `host`'s list:
-- beside that list when it runs down, flush with the button's foot (opening up) or head; beyond it when it runs across,
-- flush with the button's side. Its bottom left corner, in UIParent's units; a macro's editor opens so too
-- (UI/Hub/MacroEditor.lua).
function Folders.Place(owner, host, dir, pw, ph)
    local up, left = dir:sub(1, 2) == "up", dir:find("left$") ~= nil
    local x0, y0 = 0, 0
    if owner and owner.ux then
        local bw, bh = owner:GetWidth(), owner:GetHeight()
        local hp = host and panels[host]
        local r = hp and hp.rect
        if r and Folders.Setting(host, "flow") == "vertical" then
            x0 = left and r.x0 - GAP - pw or r.x0 + r.w + GAP
            y0 = up and owner.uy - bh / 2 or owner.uy + bh / 2 - ph
        elseif r then
            x0 = left and owner.ux + bw / 2 - pw or owner.ux - bw / 2
            y0 = up and r.y0 + r.h + GAP or r.y0 - GAP - ph
        else
            x0 = left and owner.ux + bw / 2 - pw or owner.ux - bw / 2
            y0 = up and owner.uy + bh / 2 + GAP or owner.uy - bh / 2 - GAP - ph
        end
    end
    return max(0, min(UIParent:GetWidth() - pw, x0)), max(0, min(UIParent:GetHeight() - ph, y0))
end

-- Lays out folder id's members (the hub's entries) in its list next to `owner`, its button where InfoBar put it (nil
-- when it doesn't show): ours as buttons in the list, Blizzard's widgets and other addons' map buttons over it. The
-- list shows while the folder is open.
function Folders.Layout(id, members, owner)
    local p = panel(id)
    local S = Hub.IconSize()
    local icons = Folders.Setting(id, "style") == "icons"
    local flow, per, dir = Folders.Setting(id, "flow"), Folders.Setting(id, "perLine"), Folders.Setting(id, "dir")
    local cell, edge = S + 2 * PAD, inset()
    local fb = Buttons.Get(id)
    -- one standing in another folder's list (its host): open only while that one is, above it
    local host = Folders.Host(id)
    local hp = host and panels[host]
    local hostOpen = not host or (hp ~= nil and hp:IsShown())
    if not hostOpen and all()[id] then
        all()[id].opened = nil
    end
    local level = 40 + 10 * depth(id)
    if p:GetFrameLevel() ~= level then
        p:SetFrameLevel(level)
    end
    if fb then
        arm(fb, id)
        local inside = hp and true or nil
        if hp then
            SecureHandlerSetFrameRef(fb, "up", hp)
        end
        if fb:GetAttribute("kali-in") ~= inside then
            fb:SetAttribute("kali-in", inside)
        end
        Folders.Press(fb, Folders.IsOpen(id))
    end
    -- in the registry at its place among the folders (ONE_OPEN)
    local reg, folders = registry(), Folders.List()
    for i, other in ipairs(folders) do
        if other == id then
            SecureHandlerSetFrameRef(reg, "panel" .. i, p)
        end
    end
    if reg:GetAttribute("kali-count") ~= #folders then
        reg:SetAttribute("kali-count", #folders)
    end
    -- the folders standing in it: shut with it (ON_HIDE)
    local subs = 0
    for _, e in ipairs(members) do
        if e.isFolder then
            subs = subs + 1
            SecureHandlerSetFrameRef(p, "sub" .. subs, panel(e.name))
        end
    end
    if p:GetAttribute("kali-subs") ~= subs then
        p:SetAttribute("kali-subs", subs)
    end
    -- a separator's title drawn in a list with text running down; elsewhere its rule, its title in its tooltip
    local titled = not icons and flow == "vertical"
    local shown, labels = measure(p, members, icons, cell, p:GetFrameLevel() + 5, titled, Folders.Values(id))
    for i = labels + 1, #p.labels do
        p.labels[i]:Hide()
    end
    local w, h
    local across = flow == "horizontal"
    local lines, along, thick = linesOf(shown, icons, flow, per, cell)
    p.Empty:SetShown(#shown == 0)
    if #shown == 0 then
        Buttons.SizeText(p.Empty)
        p.Empty:SetText(L.FOLDER_EMPTY)
        w, h = p.Empty:GetStringWidth() + 2 * PAD, cell
    elseif across then
        w, h = along, thick
    else
        w, h = thick, along
    end
    local pw, ph = w + 2 * edge, h + 2 * edge

    -- away from the button the way it opens (Folders.Place)
    local up, left = dir:sub(1, 2) == "up", dir:find("left$") ~= nil
    local x0, y0 = Folders.Place(owner, host, dir, pw, ph)
    p:ClearAllPoints()
    p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x0, y0)
    p:SetSize(pw, ph)
    p.rect = p.rect or {}
    p.rect.x0, p.rect.y0, p.rect.w, p.rect.h = x0, y0, pw, ph

    -- Icons: the first next to the button, each line from its side, the lines outwards from it. Texts: read as a page,
    -- from the top left whichever way the list opens, as Blizzard's menus that open upwards still read downwards (Ikar
    -- 2026-11-20, the attributes' folder opening up from the bar: "somethings off", each title under its group; then
    -- the emotes', opening to the left: "emote ordered weirdly", its columns from the right). A point `a` along a line
    -- from where lines start and `t` across them from where they start, on the screen.
    local fromRight, fromFoot = left and icons, up and icons
    local function point(a, t)
        if across then
            return fromRight and (x0 + pw - edge - a) or (x0 + edge + a), fromFoot and (y0 + edge + t) or (y0 + ph - edge - t)
        end
        return fromRight and (x0 + pw - edge - t) or (x0 + edge + t), fromFoot and (y0 + edge + a) or (y0 + ph - edge - a)
    end
    -- where each member goes: { m, cx, cy, x (the left of one with its text) }; a separator's rule across its line, as
    -- long as the line is thick less its edges, `w` x `h`
    -- its line's on the screen, for a drop's rule between two (Folders.DropTarget): the span `lo`..`hi` it takes
    -- along the line, the line's middle across it (`mid`), its thickness less its edges (`len`), which way along it
    -- runs on the screen (`dir`)
    local function alongOf(a)
        local ax, ay = point(a, 0)
        return across and ax or ay
    end
    local dir = alongOf(1) > alongOf(0) and 1 or -1
    local spots, t0 = {}, 0
    for li, line in ipairs(lines) do
        local cursor = 0
        local mx, my = point(0, t0 + line.thick / 2)
        local mid, len = across and my or mx, max(line.thick - 2 * PAD, 4)
        for _, m in ipairs(line.items) do
            local s = { m = m, line = li, mid = mid, len = len, dir = dir }
            local a0 = cursor + ((across and not icons) and PAD or 0)
            if m.sep then
                local length, room = max(line.thick - 2 * PAD, 4), m.title and cell or SEP
                s.sep, s.w, s.h, s.title = true, across and room or length, across and length or room, m.title
                s.cx, s.cy = point((across and not icons and PAD or 0) + cursor + room / 2, t0 + line.thick / 2)
                cursor = cursor + room + ((across and not icons) and SPACING or 0)
            elseif icons then
                s.cx, s.cy = point(cursor + cell / 2, t0 + cell / 2)
                cursor = cursor + cell
            elseif across then
                local start = PAD + cursor
                cursor = cursor + m.w + SPACING
                s.x, s.cy = point(start, t0 + cell / 2)
            else
                local columnLeft = x0 + edge + t0
                local _, cy = point(cursor + cell / 2, 0)
                cursor = cursor + cell
                s.x, s.cy = columnLeft + PAD + (m.bare and line.indent or 0), cy
                -- its value on the column's right: the button as wide as the column, less its edges
                if line.values and m.valueW and m.b then
                    m.w = line.thick - 2 * PAD - (m.bare and line.indent or 0)
                    m.b._alignW = m.w
                    m.b:SetWidth(m.w)
                end
            end
            local a1 = m.sep and a0 + (m.title and cell or SEP) or icons and a0 + cell or across and a0 + m.w or a0 + cell
            s.lo, s.hi = min(alongOf(a0), alongOf(a1)), max(alongOf(a0), alongOf(a1))
            spots[#spots + 1] = s
        end
        t0 = t0 + line.thick
    end
    local cells, drag = p.cells, ns.HubDrag.Current()
    for i = #spots + 1, #cells do
        cells[i] = nil
    end
    for i, spot in ipairs(spots) do
        local m, cx, cy, x = spot.m, spot.cx, spot.cy, spot.x
        if not icons and not spot.sep then
            cx = x + S / 2
        end
        local e = m.e
        if spot.sep then
            if e.name ~= drag then
                m.b:ClearAllPoints()
                m.b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            end
            Buttons.Separator(m.b, spot.w, spot.h, across, spot.title)
            m.b.ux, m.b.uy = cx, cy
            m.b:Show()
            ns.InfoBar.Keep(m.b)
        elseif m.b then
            if e.name ~= drag then
                m.b:ClearAllPoints()
                if icons then
                    m.b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
                else
                    m.b:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x, cy)
                end
            end
            m.b.ux, m.b.uy = icons and cx or x + m.w / 2, cy
            m.b:Show()
            ns.InfoBar.Keep(m.b)
        elseif e.native then
            ns.Natives.PlaceOnBar(e.name, cx, cy, p)
        else
            ns.Collect.Place(e.name, p, cx, cy)
        end
        if m.label then
            m.label:ClearAllPoints()
            m.label:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x + S + 3, cy)
            m.label:Show()
        end
        local c = cells[i] or {}
        c.name, c.x, c.y = e.name, (icons or spot.sep) and cx or x + m.w / 2, cy
        c.line, c.lo, c.hi, c.mid, c.len, c.dir, c.rows = spot.line, spot.lo, spot.hi, spot.mid, spot.len, spot.dir, across
        cells[i] = c
    end

    local open = Folders.IsOpen(id) and owner ~= nil and drag ~= id and hostOpen
    showList(p, open)
    -- closing on leaving, it's in the game's auto-hide again where the layout moved it (the game drops a list that
    -- moved), not while something is dragged
    local where = open and fb and Folders.Setting(id, "open") ~= "click" and not drag
        and string.format("%.2f %.2f %.2f %.2f", x0, y0, pw, ph)
    if where and p.hideAt ~= where then
        RegisterAutoHide(p, LEAVE_DELAY)
        AddToAutoHide(p, fb)
    end
    p.hideAt = where or nil
    if not open then
        for _, m in ipairs(shown) do
            if m.e.native or m.e.foreign then
                Buttons.PlaceHandle(m.e.name, nil)
            end
        end
    end
end

-- A drop's answer: on a folder's icon or in an empty list, a place (kind "slot"); between two members, the rule across
-- the line there, `w` x `h` (kind "line"; Ikar 2026-11-16: "highlight the line between two element, the current
-- circle is unclear").
local function answer(id, x, y, index, w, h)
    hit.side, hit.kind, hit.folder, hit.x, hit.y, hit.index = "folder", w and "line" or "slot", id, x, y, index
    hit.angle, hit.pos, hit.w, hit.h = nil, nil, w, h
    return hit
end

-- Where the rule goes for a drop between `u` and `v` (cells in the list's order, either missing at an end), next to
-- `near`, the nearest, after it or not: midway between the two when they share a line, else just past `near`'s side.
local function between(u, v, near, after)
    local pos
    if u and v and u.line == v.line and u.lo then
        pos = u.hi <= v.lo and (u.hi + v.lo) / 2 or (v.hi + u.lo) / 2
    elseif near.lo then
        local d = near.dir
        if after then
            pos = (d > 0 and near.hi or near.lo) + d * 1.5
        else
            pos = (d > 0 and near.lo or near.hi) - d * 1.5
        end
    else
        return nil
    end
    if near.rows then
        return pos, near.mid, 2, near.len
    end
    return near.mid, pos, near.len, 2
end

-- On a folder's icon, not its name, one that shows (on the bar, round the map or in an open list): that folder.
local function onIcon(ux, uy, dragged)
    local S = Hub.IconSize()
    for _, id in ipairs(Folders.List()) do
        local b = Buttons.Get(id)
        if b and b:IsVisible() and b.ux and Folders.CanHold(id, dragged) then
            local w = b:GetWidth()
            local ix = w > S + 6 and b.ux - w / 2 + S / 2 or b.ux
            if math.abs(ux - ix) <= S / 2 + 3 and math.abs(uy - b.uy) <= S / 2 + 5 then
                return id, ix
            end
        end
    end
end

-- Where a drop at (ux, uy) goes into a folder, as HubDrag.Target answers (the same table each time: read it at once):
-- on a folder's icon, last in it; among an open list's members, before the nearest or after it past its middle. Nil
-- elsewhere; a folder into none it holds, nor itself.
function Folders.DropTarget(ux, uy, dragged)
    if not dragged then
        return nil
    end
    local into, ix = onIcon(ux, uy, dragged)
    if into then
        return answer(into, ix, Buttons.Get(into).uy, nil)
    end
    -- the lists opened inward first (above those they stand in); a folder into none it holds, nor itself
    local ordered = Folders.Ordered()
    for i = #ordered, 1, -1 do
        local id = ordered[i]
        local p = panels[id]
        local r = p and p.rect
        if r and p:IsShown() and Folders.CanHold(id, dragged) and ux >= r.x0 and ux <= r.x0 + r.w and uy >= r.y0
            and uy <= r.y0 + r.h then
            -- the nearest member but the one dragged, and the members either side of it: in the line the pointer is in
            -- first (as thick as the line, edges and all), then along it, each member as long as it takes; a list in
            -- columns had the next column's member, its middle nearer than a long text's (Ikar 2026-11-20: "it switch
            -- to the right column too early, when the cursor is still on the left")
            local function away(c)
                if not c.lo then
                    return 0, (ux - c.x) ^ 2 + (uy - c.y) ^ 2
                end
                local a, t = c.rows and ux or uy, c.rows and uy or ux
                return max(math.abs(t - c.mid) - c.len / 2 - PAD, 0), max(c.lo - a, a - c.hi, 0)
            end
            local bestOff, bestAlong, nearest, at, n = nil, nil, nil, 0, 0
            for _, c in ipairs(p.cells) do
                if c.name ~= dragged then
                    n = n + 1
                    local off, along = away(c)
                    if not bestOff or off < bestOff or off == bestOff and along < bestAlong then
                        bestOff, bestAlong, nearest, at = off, along, c, n
                    end
                end
            end
            if not nearest then
                return answer(id, r.x0 + r.w / 2, r.y0 + r.h / 2, 1)
            end
            local prev, nextC, k = nil, nil, 0
            for _, c in ipairs(p.cells) do
                if c.name ~= dragged then
                    k = k + 1
                    if k == at - 1 then
                        prev = c
                    elseif k == at + 1 then
                        nextC = c
                    end
                end
            end
            local dx, dy = 0, 0
            if nextC then
                dx, dy = nextC.x - nearest.x, nextC.y - nearest.y
            elseif prev then
                dx, dy = nearest.x - prev.x, nearest.y - prev.y
            end
            -- past its middle along its line, the way the line runs (its last's next starts the next line)
            local after = (ux - nearest.x) * dx + (uy - nearest.y) * dy > 0
            if nearest.lo then
                after = ((nearest.rows and ux or uy) - (nearest.lo + nearest.hi) / 2) * nearest.dir > 0
            end
            local x, y, w, h = between(after and nearest or prev, after and nextC or nearest, nearest, after)
            if x then
                return answer(id, x, y, after and at + 1 or at, w, h)
            end
            return answer(id, nearest.x, nearest.y, after and at + 1 or at)
        end
    end
end

-- For the report and /kh status.
function Folders.Text()
    local lines = {}
    for _, id in ipairs(Folders.List()) do
        local f = all()[id]
        lines[#lines + 1] = string.format("%s: %d items, %s %s %d, %s, %s, %s%s%s%s", id, #Hub.InFolder(id),
            Folders.Setting(id, "style"), Folders.Setting(id, "flow"), Folders.Setting(id, "perLine"),
            Folders.Setting(id, "dir"), Folders.Setting(id, "open"), Folders.Setting(id, "icon"),
            f.iconOnly and ", icon only" or "", f.opened and ", open" or "",
            (f.default and ", default" or "") .. (f.overflow and ", what doesn't fit" or ""))
    end
    return #lines > 0 and table.concat(lines, "\n") or "(none)"
end
